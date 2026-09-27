"""PDF evidence report generation."""
from __future__ import annotations

import io
from datetime import datetime, timezone
from typing import Any, List

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

from cryptotrace.models import TraceResponse
from cryptotrace.utils import format_eth_amount, shorten


def generate_pdf_report(response: TraceResponse) -> bytes:
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=A4, topMargin=16*mm, bottomMargin=16*mm, leftMargin=14*mm, rightMargin=14*mm)
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle("ReportTitle", parent=styles["Title"], fontSize=18, spaceAfter=4, textColor=colors.black)
    subtitle_style = ParagraphStyle("Subtitle", parent=styles["Normal"], fontSize=9, textColor=colors.HexColor("#333333"))
    heading_style = ParagraphStyle("SectionHeading", parent=styles["Heading2"], fontSize=12, spaceBefore=12, spaceAfter=5)
    body_style = ParagraphStyle("Body", parent=styles["Normal"], fontSize=8.5, leading=11)
    mono_style = ParagraphStyle("Mono", parent=styles["Normal"], fontSize=7.5, fontName="Courier", leading=9)
    elements: List[Any] = []
    generated_at = response.case.created_at.replace("T", " ").replace("+00:00", " UTC")
    s = response.summary
    a = response.analysis
    elements += [Paragraph("CryptoTrace — Forensic Evidence Report", title_style), Paragraph(f"Generated: {generated_at}", subtitle_style), Spacer(1, 8)]
    provenance = s.vasp_provenance
    summary_rows = [
        ["Case ID", response.case.case_id], ["Created At", generated_at], ["Schema Version", response.case.schema_version],
        ["Target Wallet", s.target_wallet], ["Data Source", s.data_source.upper()],
        ["Nearest VASP", s.nearest_vasp or "None detected within hop limit"], ["VASP Type", s.vasp_type or "N/A"],
        ["Observed VASP Path Direction", s.vasp_direction or "N/A"],
        ["VASP Verification Status", provenance.verification_status if provenance else "N/A"],
        ["VASP Registry Source", provenance.source if provenance else "N/A"],
        ["VASP Source Type", provenance.source_type if provenance else "N/A"],
        ["VASP Source URL", provenance.source_url or "N/A"] if provenance else ["VASP Source URL", "N/A"],
        ["VASP Registry Notes", provenance.notes or "N/A"] if provenance else ["VASP Registry Notes", "N/A"],
        ["Requested Hop Depth", str(s.requested_hops)], ["Reached Hop Depth", str(s.reached_hops)],
        ["Depth Stop Reason", s.depth_stop_reason or "Full requested depth reached"],
        ["Minimum Transfer Threshold", f"{a.minimum_transfer_eth:g} ETH"],
        ["Transactions Examined", str(a.transactions_examined)], ["Transactions Included", str(a.transactions_included)],
        ["Transactions Filtered", str(a.transactions_filtered)], ["Filtered Below Threshold", str(a.filtered_below_eth_threshold)],
        ["Unpriced Token Transfers Seen", str(a.unpriced_token_transactions)], ["Contract Interactions", str(a.contract_interactions)],
        ["Internal ETH Transactions", str(a.internal_eth_transactions)], ["ERC-20 Transfers Traced Structurally", str(a.erc20_transactions)],
        ["Partial Data", "Yes" if a.partial_data else "No"],
        ["API Warnings", " | ".join(a.api_warnings) if a.api_warnings else "None"],
        ["Truncation", "Yes" if a.truncated else "No"], ["Truncation Reason", a.truncation_reason or "N/A"],
        ["Confidence Score (heuristic)", f"{s.confidence_score} / 100"], ["Risk Score (heuristic)", f"{s.risk_score} / 100"],
    ]
    elements.append(Paragraph("Attribution & Analysis Summary", heading_style))
    table = Table(summary_rows, colWidths=[55*mm, 120*mm])
    table.setStyle(TableStyle([("GRID",(0,0),(-1,-1),0.4,colors.black),("BACKGROUND",(0,0),(0,-1),colors.HexColor("#EFEFEF")),("FONTSIZE",(0,0),(-1,-1),8),("VALIGN",(0,0),(-1,-1),"MIDDLE"),("LEFTPADDING",(0,0),(-1,-1),5),("TOPPADDING",(0,0),(-1,-1),3),("BOTTOMPADDING",(0,0),(-1,-1),3)]))
    elements.append(table)
    if provenance:
        elements.append(Paragraph("VASP Provenance", heading_style))
        elements.append(Paragraph(
            f"Verification status: {provenance.verification_status}. "
            f"Registry source: {provenance.source}. Source type: {provenance.source_type}.",
            body_style,
        ))
        if provenance.source_url:
            elements.append(Paragraph(f"Source URL: {provenance.source_url}", mono_style))
        if provenance.notes:
            elements.append(Paragraph(f"Notes: {provenance.notes}", body_style))
    elements.append(Paragraph("Wallet Path", heading_style))
    if s.path:
        for i, addr in enumerate(s.path):
            marker = "TARGET" if i == 0 else ("VASP" if i == len(s.path)-1 else f"HOP {i}")
            elements.append(Paragraph(f"[{marker}] {addr}", mono_style))
    else:
        elements.append(Paragraph("No path to a known VASP found within the requested hop depth.", body_style))
    if s.path_hops:
        elements.append(Paragraph("Selected Path Transaction Evidence", heading_style))
        path_rows = [["Hop", "Direction", "Outgoing Tx", "Incoming Tx"]]
        for index, hop in enumerate(s.path_hops, start=1):
            path_rows.append([
                f"{index}: {shorten(hop.from_)} → {shorten(hop.to)}",
                hop.direction,
                ", ".join(shorten(tx, 8) for tx in hop.outgoing_tx_hashes) or "—",
                ", ".join(shorten(tx, 8) for tx in hop.incoming_tx_hashes) or "—",
            ])
        path_table = Table(path_rows, colWidths=[60*mm, 25*mm, 45*mm, 45*mm], repeatRows=1)
        path_table.setStyle(TableStyle([
            ("GRID", (0, 0), (-1, -1), 0.35, colors.black),
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#DDDDDD")),
            ("FONTSIZE", (0, 0), (-1, -1), 6.5),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ]))
        elements.append(path_table)
        elements.append(Paragraph(
            "Direction describes the observed transaction flow across the selected shortest path. Mixed means both directions were observed across one or more path hops; it does not prove ownership or control.",
            body_style,
        ))
    elements.append(Paragraph("Scoring Breakdown", heading_style))
    for breakdown in (s.confidence_breakdown, s.risk_breakdown):
        if not breakdown:
            continue
        elements.append(Paragraph(
            f"{breakdown.score_type.title()} — base score: {breakdown.base_score}, final score: {breakdown.final_score}",
            body_style,
        ))
        rows = [["Factor", "Points", "Explanation"]]
        for factor in breakdown.factors:
            points = f"{factor.points:+d}" if factor.points else "0"
            rows.append([factor.label, points, factor.explanation])
        factor_table = Table(rows, colWidths=[47*mm, 18*mm, 110*mm], repeatRows=1)
        factor_table.setStyle(TableStyle([
            ("GRID", (0, 0), (-1, -1), 0.35, colors.black),
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#DDDDDD")),
            ("FONTSIZE", (0, 0), (-1, -1), 7),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("TOPPADDING", (0, 0), (-1, -1), 2),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 2),
        ]))
        elements.append(factor_table)
        elements.append(Spacer(1, 4))
    if response.patterns:
        elements.append(Paragraph("Investigation Pattern Indicators", heading_style))
        pattern_rows = [["Indicator", "Severity", "Nodes", "Evidence"]]
        for pattern in response.patterns:
            nodes_text = ", ".join(shorten(node, 8) for node in pattern.node_ids) if pattern.node_ids else "Graph-wide"
            evidence_parts = []
            for key, value in pattern.evidence.items():
                evidence_parts.append(f"{key}: {value}")
            evidence_text = "; ".join(evidence_parts) if evidence_parts else "See description"
            pattern_rows.append([pattern.label, pattern.severity, nodes_text, evidence_text])
            elements.append(Paragraph(f"<b>{pattern.label}</b> — {pattern.description}", body_style))
        pattern_table = Table(pattern_rows, colWidths=[42*mm, 23*mm, 38*mm, 90*mm], repeatRows=1)
        pattern_table.setStyle(TableStyle([
            ("GRID", (0, 0), (-1, -1), 0.35, colors.black),
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#DDDDDD")),
            ("FONTSIZE", (0, 0), (-1, -1), 6.5),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("TOPPADDING", (0, 0), (-1, -1), 2),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 2),
        ]))
        elements.append(pattern_table)
        elements.append(Paragraph(
            "Pattern indicators are graph-derived heuristics. They describe transaction structures and timing only; they do not prove illicit activity, intent, ownership, or control.",
            body_style,
        ))

    elements.append(Paragraph("Scoring Rationale", heading_style))
    for note in s.scoring_notes:
        elements.append(Paragraph(f"• {note}", body_style))
    elements.append(Paragraph("Transaction History", heading_style))
    if response.edges:
        rows = [["From", "To", "Asset / Amount", "Type", "Tx Hash", "Timestamp"]]
        for e in sorted(response.edges, key=lambda x: x.timestamp):
            if e.asset_type == "contract_interaction":
                amount_text = "Contract interaction"
            elif e.asset_symbol == "ETH" or e.asset_type in {"native_eth", "internal_eth"}:
                amount_text = format_eth_amount(e.amount)
            else:
                amount_text = f"{e.amount:g} {e.asset_symbol or 'TOKEN'}".strip()
            rows.append([shorten(e.from_), shorten(e.to), amount_text, e.transaction_type, shorten(e.tx_hash, 8), e.timestamp[:19].replace("T", " ")])
        tx_table = Table(rows, colWidths=[28*mm,28*mm,38*mm,27*mm,30*mm,38*mm], repeatRows=1)
        tx_table.setStyle(TableStyle([("GRID",(0,0),(-1,-1),0.35,colors.black),("BACKGROUND",(0,0),(-1,0),colors.HexColor("#DDDDDD")),("FONTSIZE",(0,0),(-1,-1),6.2),("FONTNAME",(0,0),(-1,0),"Helvetica-Bold"),("TOPPADDING",(0,0),(-1,-1),2),("BOTTOMPADDING",(0,0),(-1,-1),2)]))
        elements.append(tx_table)
    else:
        elements.append(Paragraph("No eligible graph transfers were included in this trace. Note that ERC-20 transfers may be included structurally without ETH/USD pricing.", body_style))
    elements.append(Spacer(1, 10))
    elements.append(Paragraph("Disclaimer", heading_style))
    elements.append(Paragraph(s.disclaimer + " The 0.0005 ETH rule is a per-transfer filter and does not by itself detect transaction splitting. VASP registry records in this prototype are demonstration records unless explicitly marked verified.", body_style))
    doc.build(elements)
    return buffer.getvalue()
