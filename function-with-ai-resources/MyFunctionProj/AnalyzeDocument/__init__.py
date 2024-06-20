import logging
import os
import json

from azure.functions import HttpRequest, HttpResponse
from azure.core.credentials import AzureKeyCredential
from azure.ai.formrecognizer import DocumentAnalysisClient
from azure.identity import DefaultAzureCredential
from typing import List, Dict


endpoint = "https://dij8o6ch.cognitiveservices.azure.com/"

def main(req: HttpRequest) -> HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')


    try:
        # リクエストヘッダーの内容をログにダンプ
        req_headers = dict(req.headers)
        logging.info(f"Request headers: {json.dumps(req_headers, indent=2)}")

        req_body = req.get_json()
        logging.info(f"Request body: {json.dumps(req_body, indent=2)}")
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

    analyze_read()

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
    return {
        "recordId": record.get("recordId"),
        "data": {
            "contentTextPremium": "This is a static response from premium",
            "error": {}
        }
    }

def format_bounding_box(bounding_box):
    if not bounding_box:
        return "N/A"
    return ", ".join(["[{}, {}]".format(p.x, p.y) for p in bounding_box])

def analyze_read():
    # sample document
    formUrl = "https://raw.githubusercontent.com/Azure-Samples/cognitive-services-REST-api-samples/master/curl/form-recognizer/sample-layout.pdf"

    key = os.getenv("FORM_RECOGNIZER_KEY")
    if key:
        credential = AzureKeyCredential(key)
    else:
        credential = DefaultAzureCredential()

    document_analysis_client = DocumentAnalysisClient(
            endpoint=endpoint, credential=credential
    )
    
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
