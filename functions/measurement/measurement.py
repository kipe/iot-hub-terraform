import os
import json
import dataclasses
import tempfile
from typing import TYPE_CHECKING, Literal, Optional, List
import arrow
from dotenv import load_dotenv
import pymongo

if TYPE_CHECKING:
    from scaleway_functions_python.framework.v1.hints import Context, Event, Response

load_dotenv()
DOCUMENTDB_DATABASE_CERTIFICATE = os.environ["DOCUMENTDB_DATABASE_CERTIFICATE"]
DOCUMENTDB_DATABASE_IP = os.environ["DOCUMENTDB_DATABASE_IP"]
DOCUMENTDB_DATABASE_NAME = os.environ["DOCUMENTDB_DATABASE_NAME"]
DOCUMENTDB_DATABASE_PASSWORD = os.environ["DOCUMENTDB_DATABASE_PASSWORD"]
DOCUMENTDB_DATABASE_PORT = int(os.environ["DOCUMENTDB_DATABASE_PORT"])
DOCUMENTDB_DATABASE_USER = os.environ["DOCUMENTDB_DATABASE_USER"]


class ArrowJSONEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, arrow.Arrow):
            return obj.for_json()
        return super().default(obj)


@dataclasses.dataclass
class IncomingMeasurement:
    device: str
    type: Literal["temperature"]
    value: float
    timestamp: Optional[arrow.Arrow] = None

    def __post_init__(self):
        if not self.timestamp:
            self.timestamp = arrow.utcnow()
        else:
            self.timestamp = arrow.get(self.timestamp).to("utc")


@dataclasses.dataclass
class MeasurementRequest:
    devices: List[str]
    type: Literal["temperature"]
    start: Optional[arrow.Arrow] = None
    end: Optional[arrow.Arrow] = None

    def __post_init__(self):
        if not isinstance(self.devices, list):
            self.devices = self.devices.split(",")
        if not self.start:
            self.start = arrow.utcnow().floor("day")
        else:
            self.start = arrow.get(self.start).to("utc")
        if not self.end:
            self.end = arrow.utcnow().ceil("day")
        else:
            self.end = arrow.get(self.end).to("utc")


@dataclasses.dataclass
class MeasurementPoint:
    timestamp: arrow.Arrow
    value: float


@dataclasses.dataclass
class MeasurementSeries:
    device: str
    type: Literal["temperature"]
    points: List[MeasurementPoint]


@dataclasses.dataclass
class MeasurementResponse:
    start: arrow.Arrow
    end: arrow.Arrow
    series: List[MeasurementSeries]


def serve(event: "Event", _context: "Context") -> "Response":
    with tempfile.NamedTemporaryFile(mode="w") as cert_file:
        cert_file.write(DOCUMENTDB_DATABASE_CERTIFICATE)
        cert_file.seek(0)

        with pymongo.MongoClient(
            host=DOCUMENTDB_DATABASE_IP,
            port=DOCUMENTDB_DATABASE_PORT,
            username=DOCUMENTDB_DATABASE_USER,
            password=DOCUMENTDB_DATABASE_PASSWORD,
            tls=True,
            tlsCAFile=cert_file.name,
            authMechanism="PLAIN",
        ) as client:
            request = MeasurementRequest(**event.get("queryStringParameters"))
            measurement_serie = {}

            for day in arrow.Arrow.range("day", request.start, request.end):
                timeseries_key = f"measurements-{day.format('YYYY-MM-DD')}"
                db = client[DOCUMENTDB_DATABASE_NAME]
                for device in request.devices:
                    series = db[timeseries_key].find_one({"device": device})
                    if not series:
                        continue
                    if device not in measurement_serie:
                        measurement_serie[device] = []
                    measurement_serie[device].extend(
                        {
                            "timestamp": arrow.Arrow.fromdatetime(
                                point["timestamp"],
                                "utc",
                            ),
                            "value": point["value"],
                        }
                        for point in series.get(request.type)
                    )

            response = MeasurementResponse(
                start=request.start,
                end=request.end,
                series=[
                    MeasurementSeries(
                        device=device,
                        type=request.type,
                        points=[
                            MeasurementPoint(point["timestamp"], point["value"])
                            for point in filter(
                                lambda x: request.start
                                <= x["timestamp"]
                                <= request.end,
                                measurement_serie.get(device, []),
                            )
                        ],
                    )
                    for device in request.devices
                ],
            )

            return {
                "body": json.dumps(
                    dataclasses.asdict(response),
                    cls=ArrowJSONEncoder,
                ),
                "headers": {"Content-Type": ["application/json"]},
                "statusCode": 200,
            }


def ingest(event: "Event", _context: "Context") -> "Response":
    with tempfile.NamedTemporaryFile(mode="w") as cert_file:
        cert_file.write(DOCUMENTDB_DATABASE_CERTIFICATE)
        cert_file.seek(0)

        with pymongo.MongoClient(
            host=DOCUMENTDB_DATABASE_IP,
            port=DOCUMENTDB_DATABASE_PORT,
            username=DOCUMENTDB_DATABASE_USER,
            password=DOCUMENTDB_DATABASE_PASSWORD,
            tls=True,
            tlsCAFile=cert_file.name,
            authMechanism="PLAIN",
        ) as client:
            meas = IncomingMeasurement(**json.loads(event.get("body") or "{}"))
            timeseries_key = f"measurements-{meas.timestamp.format('YYYY-MM-DD')}"
            db = client[DOCUMENTDB_DATABASE_NAME]
            db[meas.device].update_one(
                {"device": meas.device},
                {
                    "$set": {
                        "last_value": meas.value,
                        "last_timestamp": meas.timestamp.datetime,
                    },
                },
                upsert=True,
            )
            db[timeseries_key].update_one(
                {"device": meas.device},
                {
                    "$push": {
                        f"{meas.type}": {
                            "value": meas.value,
                            "timestamp": meas.timestamp.datetime,
                        }
                    }
                },
                upsert=True,
            )

            return {
                "body": json.dumps(
                    dataclasses.asdict(meas),
                    cls=ArrowJSONEncoder,
                ),
                "headers": {"Content-Type": ["application/json"]},
                "statusCode": 200,
            }


def measurement(event: "Event", context: "Context") -> "Response":
    if event.get("httpMethod").lower() == "get":
        return serve(event, context)
    if event.get("httpMethod").lower() == "post":
        return ingest(event, context)
    return {
        "body": "unsupported method",
        "statusCode": 400,
    }


if __name__ == "__main__":
    from scaleway_functions_python import local

    server = local.LocalFunctionServer()
    server.add_handler(measurement)
    server.serve(port=8080)
