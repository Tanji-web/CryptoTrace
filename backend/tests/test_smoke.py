"""Small smoke checks for the modular backend."""
from cryptotrace import build_trace_response, generate_pdf_report, trace_wallet


def test_mock_trace_and_pdf():
    result = trace_wallet("0x1234567890123456789012345678901234567890", max_hops=2)
    response = build_trace_response(result, 2)
    pdf = generate_pdf_report(response)
    assert response.nodes
    assert response.edges
    assert pdf.startswith(b"%PDF")
