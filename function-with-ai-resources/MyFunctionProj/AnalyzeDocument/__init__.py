import logging
import os
import json

from azure.functions import HttpRequest, HttpResponse
from azure.core.credentials import AzureKeyCredential
from azure.ai.formrecognizer import DocumentAnalysisClient
from azure.identity import DefaultAzureCredential
from typing import List, Dict


endpoint = os.getenv("DOCUMENT_INTELLIGENCE_ENDPOINT")

def main(req: HttpRequest) -> HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')


    try:
        # リクエストヘッダーの内容をログにダンプ
        req_headers = dict(req.headers)
        logging.info(f"Request headers: {json.dumps(req_headers, indent=2)}")

        req_body = req.get_json()
        dump_req_body = req_body.copy()
        # Delete "data" field value from dump_req_body to avoid logging binary data
        if dump_req_body.get("values"):
            for record in dump_req_body.get("values"):
                if record.get("data"):
                    record["data"]["images"]["data"] = "binary data"

        logging.info(f"Request body: {json.dumps(dump_req_body, indent=2)}")
    except ValueError:
        return HttpResponse(
            "Invalid JSON",
            status_code=400
        )

    values = req_body.get('values')
    if not values:
        return HttpResponse(
            "No 'values' field in request body",
            status_code=400
        )

    response_values = [process_record(record) for record in values]
    return HttpResponse(
        json.dumps({"values": response_values}),
        status_code=200,
        mimetype="application/json",
        headers={
            'Content-Type': 'application/json'
        }
    )


def process_record(record: Dict) -> Dict:
    # {
    #   "recordId": "3",
    #   "data": {
    #     "images": {
    #       "$type": "file",
    #       "url": null,
    #       "data": "binary data",
    #       "width": 929,
    #       "height": 2000,
    #       "originalWidth": 1895,
    #       "originalHeight": 4077,
    #       "rotationFromOriginal": 0,
    #       "contentOffset": 0,
    #       "pageNumber": 0,
    #       "contentType": "image/jpeg"
    #     },
    #     "url": "https://datasaj8o6ch.blob.core.windows.net/data/%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%BC%E3%83%B3%E3%82%B7%E3%83%A7%E3%83%83%E3%83%88_16-6-2024_13843_console.equinix.com.jpeg"
    #   }
    # }
    content = ""
    try:
        content = analyze_read(url=record.get("data").get("url"))
    except Exception as e:
        logging.error(f"Error occurred: {e}")
        return HttpResponse(
            "Error occurred while analyzing document" + str(e),
            status_code=500
        )

    return {
        "recordId": record.get("recordId"),
        "data": {
            "contentTextPremium": "This is a static response from premium: " + content,
            "error": {}
        }
    }

def format_bounding_box(bounding_box):
    if not bounding_box:
        return "N/A"
    return ", ".join(["[{}, {}]".format(p.x, p.y) for p in bounding_box])

def analyze_read(url: str):
    # sample document
    #formUrl = "https://raw.githubusercontent.com/Azure-Samples/cognitive-services-REST-api-samples/master/curl/form-recognizer/sample-layout.pdf"
    formUrl = url
    key = os.getenv("FORM_RECOGNIZER_KEY")
    if key:
        credential = AzureKeyCredential(key)
    else:
        credential = DefaultAzureCredential()

    document_analysis_client = DocumentAnalysisClient(
            endpoint=endpoint, credential=credential
    )
    
    logging.info(f"formURL: {formUrl}")
    poller = document_analysis_client.begin_analyze_document_from_url(
            "prebuilt-read", formUrl)
    result = poller.result()

    print ("Document contains content: ", result.content)
    
    for idx, style in enumerate(result.styles):
        print(
            "Document contains {} content".format(
                "handwritten" if style.is_handwritten else "no handwritten"
            )
        )

    for page in result.pages:
        print("----Analyzing Read from page #{}----".format(page.page_number))
        print(
            "Page has width: {} and height: {}, measured with unit: {}".format(
                page.width, page.height, page.unit
            )
        )

        for line_idx, line in enumerate(page.lines):
            print(
                "...Line # {} has text content '{}' within bounding box '{}'".format(
                    line_idx,
                    line.content,
                    format_bounding_box(line.polygon),
                )
            )

        for word in page.words:
            print(
                "...Word '{}' has a confidence of {}".format(
                    word.content, word.confidence
                )
            )
    print("----------------------------------------")
    return result.content
