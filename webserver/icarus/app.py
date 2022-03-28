import configparser
import csv
import io
import os

from flask import Flask, make_response, render_template
from pymongo.mongo_client import MongoClient
from pymongo.server_api import ServerApi

app = Flask(__name__)

config = configparser.ConfigParser()
config.read(os.path.join(os.path.dirname(__file__), "config.ini"))
mongo = config["MongoDB"]

conn_str = (
    f"mongodb+srv://{mongo['username']}:{mongo['password']}"
    f"@{mongo['host']}/{mongo['database']}"
)
client = MongoClient(conn_str, server_api=ServerApi("1"),
                     serverSelectionTimeoutMS=5000)
db = client.covid


@app.route("/")
def home():
    return render_template("home.html")


@app.route("/secure/")
@app.route("/secure/<collection>")
def data(collection=None):
    if collection is None:
        return render_template("data.html")
    fields = ["week", "tests", "positives"]
    text_stream = io.StringIO()
    # ignore _id field
    writer = csv.DictWriter(text_stream, fields, extrasaction='ignore')
    writer.writeheader()
    for document in db[f"{collection}.weekly"].find():
        writer.writerow(document)
    response = make_response(text_stream.getvalue())
    response.headers["Content-Disposition"] = \
        f"attachment; filename={collection}.csv"
    response.headers["Content-Type"] = "text/csv"
    return response
