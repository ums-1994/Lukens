"""
Finance export routes for financial data export functionality
Handles CSV and Excel exports for proposal summaries and client reports
"""
from flask import Blueprint, request, jsonify, send_file
from typing import Optional, Dict, Any, List
from datetime import datetime, timedelta
import csv
import io
import os
import tempfile
from api.utils.decorators import token_required, finance_required
from api.utils.database import get_db_connection
import psycopg2.extras
import json

bp = Blueprint('finance_export', __name__)

def _extract_amount_from_content(content_data):
    """Extract financial amount from proposal content using same logic as frontend"""
    if not content_data:
        return 0.0
    
    def _parse_num(v):
        if v is None:
            return 0
        if isinstance(v, (int, float)):
            return float(v)
        cleaned = str(v).replace(',', '').replace('R', '').replace('$', '').strip()
        try:
            return float(cleaned)
        except:
            return 0.0
    
    # Try direct amount fields first
    if isinstance(content_data, dict):
        for key in ['budget', 'amount', 'total', 'value', 'price']:
            if key in content_data:
                amount = _parse_num(content_data[key])
                if amount > 0:
                    return amount
    
    # Try to extract from pricing tables in sections
    if isinstance(content_data, dict) and 'sections' in content_data:
        total = 0.0
        for section in content_data.get('sections', []):
            if not isinstance(section, dict):
                continue
                
            # Check for tables in section
            for table in section.get('tables', []):
                if isinstance(table, dict) and table.get('type') == 'price':
                    cells = table.get('cells', [])
                    if isinstance(cells, list) and len(cells) > 1:
                        # Look for total column
                        header_row = cells[0] if isinstance(cells[0], list) else []
                        total_col_idx = None
                        
                        for i, header in enumerate(header_row):
                            if isinstance(header, str) and 'total' in header.lower():
                                total_col_idx = i
                                break
                        
                        if total_col_idx is not None:
                            for row in cells[1:]:
                                if isinstance(row, list) and len(row) > total_col_idx:
                                    total += _parse_num(row[total_col_idx])
        
        return total
    
    return 0.0

def _format_currency(amount):
    """Format amount as South African Rand"""
    if amount <= 0:
        return "R 0"
    return f"R {amount:,.2f}"

def _get_proposals_with_financials(user_id=None, status_filter=None, date_from=None, date_to=None):
    """Get proposals with financial calculations"""
    proposals = []
    
    query = """
        SELECT p.id, p.title, p.client_name, p.status, p.created_at, p.updated_at,
               p.content, u.full_name as created_by
        FROM proposals p
        LEFT JOIN users u ON p.created_by = u.id
        WHERE 1=1
    """
    params = []
    
    if status_filter:
        query += " AND LOWER(p.status) LIKE %s"
        params.append(f"%{status_filter.lower()}%")
    
    if date_from:
        query += " AND p.created_at >= %s"
        params.append(date_from)
    
    if date_to:
        query += " AND p.created_at <= %s"
        params.append(date_to)
    
    query += " ORDER BY p.created_at DESC"
    
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cursor.execute(query, params)
            rows = cursor.fetchall()
            
            for row in rows:
                # Extract amount from content
                amount = 0.0
                if row['content']:
                    try:
                        content_data = json.loads(row['content']) if isinstance(row['content'], str) else row['content']
                        amount = _extract_amount_from_content(content_data)
                    except:
                        pass
                
                # Calculate days in current status
                days_in_status = 0
                if row['updated_at']:
                    days_in_status = (datetime.now() - row['updated_at']).days
                
                proposal = {
                    'id': row['id'],
                    'title': row['title'],
                    'client_name': row['client_name'],
                    'status': row['status'],
                    'created_at': row['created_at'],
                    'updated_at': row['updated_at'],
                    'created_by': row['created_by'],
                    'amount': amount,
                    'formatted_amount': _format_currency(amount),
                    'days_in_status': days_in_status
                }
                proposals.append(proposal)
                
    except Exception as e:
        print(f"Error fetching proposals: {e}")
        return []
    
    return proposals

def _get_client_portfolio_data(proposals):
    """Aggregate proposal data by client"""
    client_data = {}
    
    for proposal in proposals:
        client = proposal['client_name'] or 'Unknown Client'
        
        if client not in client_data:
            client_data[client] = {
                'client_name': client,
                'total_proposals': 0,
                'total_amount': 0.0,
                'approved_proposals': 0,
                'approved_amount': 0.0,
                'pending_proposals': 0,
                'pending_amount': 0.0,
                'proposals': []
            }
        
        client_data[client]['total_proposals'] += 1
        client_data[client]['total_amount'] += proposal['amount']
        client_data[client]['proposals'].append(proposal)
        
        status = proposal['status'].lower()
        if 'approved' in status or 'signed' in status:
            client_data[client]['approved_proposals'] += 1
            client_data[client]['approved_amount'] += proposal['amount']
        elif 'pending' in status or 'review' in status:
            client_data[client]['pending_proposals'] += 1
            client_data[client]['pending_amount'] += proposal['amount']
    
    # Calculate additional metrics
    for client in client_data.values():
        client['success_rate'] = (client['approved_proposals'] / client['total_proposals'] * 100) if client['total_proposals'] > 0 else 0
        client['average_deal_size'] = client['total_amount'] / client['total_proposals'] if client['total_proposals'] > 0 else 0
        client['formatted_total'] = _format_currency(client['total_amount'])
        client['formatted_average'] = _format_currency(client['average_deal_size'])
    
    return list(client_data.values())

def _generate_csv_summary(proposals):
    """Generate CSV for proposal financial summary"""
    output = io.StringIO()
    writer = csv.writer(output)
    
    # Header
    writer.writerow([
        'Proposal ID', 'Title', 'Client', 'Status', 
        'Created Date', 'Updated Date', 'Amount (ZAR)', 
        'Days in Status', 'Created By'
    ])
    
    # Data rows
    for proposal in proposals:
        writer.writerow([
            proposal['id'],
            proposal['title'],
            proposal['client_name'],
            proposal['status'],
            proposal['created_at'].strftime('%Y-%m-%d') if proposal['created_at'] else '',
            proposal['updated_at'].strftime('%Y-%m-%d') if proposal['updated_at'] else '',
            f"{proposal['amount']:.2f}",
            proposal['days_in_status'],
            proposal['created_by']
        ])
    
    return output.getvalue()

def _generate_csv_client_report(client_data):
    """Generate CSV for client financial report"""
    output = io.StringIO()
    writer = csv.writer(output)
    
    # Header
    writer.writerow([
        'Client Name', 'Total Proposals', 'Total Amount (ZAR)', 
        'Approved Proposals', 'Approved Amount (ZAR)', 
        'Pending Proposals', 'Pending Amount (ZAR)',
        'Success Rate (%)', 'Average Deal Size (ZAR)'
    ])
    
    # Data rows
    for client in client_data:
        writer.writerow([
            client['client_name'],
            client['total_proposals'],
            f"{client['total_amount']:.2f}",
            client['approved_proposals'],
            f"{client['approved_amount']:.2f}",
            client['pending_proposals'],
            f"{client['pending_amount']:.2f}",
            f"{client['success_rate']:.1f}",
            f"{client['average_deal_size']:.2f}"
        ])
    
    return output.getvalue()

@bp.route("/finance/export/proposal-summary", methods=["GET", "OPTIONS"])
@token_required
def export_proposal_summary(username=None, user_id=None, email=None):
    """Export proposal financial summary"""
    try:
        # Get query parameters
        format_type = request.args.get('format', 'csv').lower()
        status_filter = request.args.get('status')
        date_from = request.args.get('date_from')
        date_to = request.args.get('date_to')
        
        # Get proposals data
        proposals = _get_proposals_with_financials(
            user_id=user_id,
            status_filter=status_filter,
            date_from=date_from,
            date_to=date_to
        )
        
        if format_type == 'csv':
            csv_data = _generate_csv_summary(proposals)
            
            # Create file in memory
            output = io.BytesIO()
            output.write(csv_data.encode('utf-8'))
            output.seek(0)
            
            filename = f"proposal_summary_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
            
            return send_file(
                output,
                as_attachment=True,
                download_name=filename,
                mimetype='text/csv'
            )
        
        else:
            return jsonify({'error': 'Only CSV format is currently supported'}), 400
            
    except Exception as e:
        print(f"Error exporting proposal summary: {e}")
        return jsonify({'error': 'Failed to generate export'}), 500

@bp.route("/finance/export/client-report", methods=["GET", "OPTIONS"])
@token_required
def export_client_report(username=None, user_id=None, email=None):
    """Export client financial report"""
    try:
        # Get query parameters
        format_type = request.args.get('format', 'csv').lower()
        status_filter = request.args.get('status')
        date_from = request.args.get('date_from')
        date_to = request.args.get('date_to')
        
        # Get proposals data
        proposals = _get_proposals_with_financials(
            user_id=user_id,
            status_filter=status_filter,
            date_from=date_from,
            date_to=date_to
        )
        
        # Aggregate by client
        client_data = _get_client_portfolio_data(proposals)
        
        if format_type == 'csv':
            csv_data = _generate_csv_client_report(client_data)
            
            # Create file in memory
            output = io.BytesIO()
            output.write(csv_data.encode('utf-8'))
            output.seek(0)
            
            filename = f"client_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
            
            return send_file(
                output,
                as_attachment=True,
                download_name=filename,
                mimetype='text/csv'
            )
        
        else:
            return jsonify({'error': 'Only CSV format is currently supported'}), 400
            
    except Exception as e:
        print(f"Error exporting client report: {e}")
        return jsonify({'error': 'Failed to generate export'}), 500

@bp.route("/finance/export/summary-stats", methods=["GET", "OPTIONS"])
@token_required
def get_export_summary_stats(username=None, user_id=None, email=None):
    """Get summary statistics for export dialog"""
    try:
        # Get basic counts
        with get_db_connection() as conn:
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Total proposals
            cursor.execute("SELECT COUNT(*) as total FROM proposals")
            total_proposals = cursor.fetchone()['total']
            
            # Proposals by status
            cursor.execute("""
                SELECT status, COUNT(*) as count 
                FROM proposals 
                GROUP BY status 
                ORDER BY count DESC
            """)
            status_breakdown = cursor.fetchall()
            
            # Date range
            cursor.execute("""
                SELECT MIN(created_at) as earliest, MAX(created_at) as latest 
                FROM proposals
            """)
            date_range = cursor.fetchone()
        
        return jsonify({
            'total_proposals': total_proposals,
            'status_breakdown': status_breakdown,
            'date_range': date_range,
            'supported_formats': ['csv'],
            'report_types': ['proposal_summary', 'client_report']
        })
        
    except Exception as e:
        print(f"Error getting export stats: {e}")
        return jsonify({'error': 'Failed to get export statistics'}), 500
