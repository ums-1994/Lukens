import json


def test_rich_formatting_schema_round_trip():
    payload = {
        "title": "Formatting Test",
        "sections": [
            {
                "id": "sec-1",
                "title": "Executive Summary",
                "content": "Hello world",
                "paragraphAlignment": "justify",
                "lineSpacing": "1.5",
                "richParagraphs": [
                    {
                        "alignment": "justify",
                        "spacing": "1.5",
                        "listType": "bullet",
                        "spans": [
                            {
                                "text": "Hello world",
                                "bold": True,
                                "italic": False,
                                "underline": True,
                                "strike": False,
                                "fontFamily": "Arial",
                                "fontSize": 14,
                            }
                        ],
                    }
                ],
                "richContentDelta": [
                    {"insert": "Hello world"},
                    {
                        "insert": "\n",
                        "attributes": {
                            "align": "justify",
                            "line-height": 1.5,
                            "list": "bullet",
                        },
                    },
                ],
            }
        ],
        "metadata": {"version": 1},
    }

    serialized = json.dumps(payload)
    restored = json.loads(serialized)

    section = restored["sections"][0]
    assert section["paragraphAlignment"] == "justify"
    assert section["lineSpacing"] == "1.5"
    assert section["richParagraphs"][0]["spans"][0]["fontFamily"] == "Arial"
    assert section["richParagraphs"][0]["spans"][0]["fontSize"] == 14
    assert section["richContentDelta"][1]["attributes"]["line-height"] == 1.5
