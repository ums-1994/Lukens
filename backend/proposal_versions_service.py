"""
Proposal Versions Service
Handles all database operations for proposal versions using PostgreSQL
"""

import os
import psycopg2
import psycopg2.extras
from typing import List, Dict, Any, Optional
from datetime import datetime
import json

class ProposalVersionsService:
    def __init__(self):
        self.connection_params = {
            'host': os.getenv("DB_HOST", "localhost"),
            'port': int(os.getenv("DB_PORT", "5432")),
            'dbname': os.getenv("DB_NAME", "proposal_sow_builder"),
            'user': os.getenv("DB_USER", "postgres"),
            'password': os.getenv("DB_PASSWORD", os.getenv("DB_PASS", "Password123"))
        }
    
    def get_connection(self):
        """Get a new database connection"""
        return psycopg2.connect(**self.connection_params)
    
    def create_version(self, proposal_id: str, content: Dict[str, Any], 
                      created_by: str, version_number: Optional[int] = None) -> Dict[str, Any]:
        """Create a new proposal version"""
        conn = None
        try:
            conn = self.get_connection()
            cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get next version number if not provided
            if version_number is None:
                cur.execute("""
                    SELECT COALESCE(MAX(version_number), 0) + 1 as next_version
                    FROM proposal_versions 
                    WHERE proposal_id = %s
                """, (proposal_id,))
                result = cur.fetchone()
                version_number = result['next_version'] if result else 1
            
            # Convert created_by to UUID if it's not already one
            try:
                # Try to parse as UUID
                import uuid
                user_uuid = str(uuid.UUID(created_by))
            except ValueError:
                # If not a valid UUID, use a default UUID
                user_uuid = str(uuid.uuid5(uuid.NAMESPACE_DNS, created_by))
            
            # Insert new version
            cur.execute("""
                INSERT INTO proposal_versions (proposal_id, version_number, content, created_by)
                VALUES (%s, %s, %s, %s)
                RETURNING id, created_at
            """, (proposal_id, version_number, json.dumps(content), user_uuid))
            
            result = cur.fetchone()
            conn.commit()
            
            return {
                'id': str(result['id']),
                'proposal_id': proposal_id,
                'version_number': version_number,
                'content': content,
                'created_by': created_by,
                'created_at': result['created_at'].isoformat()
            }
            
        except Exception as e:
            if conn:
                conn.rollback()
            raise e
        finally:
            if conn:
                conn.close()
    
    def get_versions(self, proposal_id: str) -> List[Dict[str, Any]]:
        """Get all versions for a proposal, ordered by version number desc"""
        conn = None
        try:
            conn = self.get_connection()
            cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cur.execute("""
                SELECT id, proposal_id, version_number, content, created_by, created_at
                FROM proposal_versions 
                WHERE proposal_id = %s
                ORDER BY version_number DESC, created_at DESC
            """, (proposal_id,))
            
            results = cur.fetchall()
            versions = []
            
            for row in results:
                versions.append({
                    'id': str(row['id']),
                    'proposal_id': str(row['proposal_id']),
                    'version_number': row['version_number'],
                    'content': row['content'],
                    'created_by': str(row['created_by']) if row['created_by'] else None,
                    'created_at': row['created_at'].isoformat()
                })
            
            return versions
            
        except Exception as e:
            raise e
        finally:
            if conn:
                conn.close()
    
    def get_version(self, proposal_id: str, version_id: str) -> Optional[Dict[str, Any]]:
        """Get a specific version by ID"""
        conn = None
        try:
            conn = self.get_connection()
            cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cur.execute("""
                SELECT id, proposal_id, version_number, content, created_by, created_at
                FROM proposal_versions 
                WHERE proposal_id = %s AND id = %s
            """, (proposal_id, version_id))
            
            result = cur.fetchone()
            if not result:
                return None
            
            return {
                'id': str(result['id']),
                'proposal_id': str(result['proposal_id']),
                'version_number': result['version_number'],
                'content': result['content'],
                'created_by': str(result['created_by']) if result['created_by'] else None,
                'created_at': result['created_at'].isoformat()
            }
            
        except Exception as e:
            raise e
        finally:
            if conn:
                conn.close()
    
    def delete_version(self, proposal_id: str, version_id: str) -> bool:
        """Delete a specific version"""
        conn = None
        try:
            conn = self.get_connection()
            cur = conn.cursor()
            
            cur.execute("""
                DELETE FROM proposal_versions 
                WHERE proposal_id = %s AND id = %s
            """, (proposal_id, version_id))
            
            deleted_count = cur.rowcount
            conn.commit()
            
            return deleted_count > 0
            
        except Exception as e:
            if conn:
                conn.rollback()
            raise e
        finally:
            if conn:
                conn.close()
    
    def get_version_diff(self, proposal_id: str, from_version_id: str, to_version_id: str) -> Dict[str, Any]:
        """Get differences between two versions"""
        conn = None
        try:
            conn = self.get_connection()
            cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            # Get both versions
            cur.execute("""
                SELECT id, version_number, content, created_at
                FROM proposal_versions 
                WHERE proposal_id = %s AND id IN (%s, %s)
            """, (proposal_id, from_version_id, to_version_id))
            
            results = cur.fetchall()
            if len(results) != 2:
                raise ValueError("One or both versions not found")
            
            # Find from and to versions
            from_version = None
            to_version = None
            
            for row in results:
                if str(row['id']) == from_version_id:
                    from_version = row
                elif str(row['id']) == to_version_id:
                    to_version = row
            
            if not from_version or not to_version:
                raise ValueError("One or both versions not found")
            
            # Calculate differences
            from_content = from_version['content']
            to_content = to_version['content']
            
            added = []
            modified = []
            removed = []
            
            # Find all unique section keys
            all_keys = set(from_content.keys()) | set(to_content.keys())
            
            for key in all_keys:
                from_value = from_content.get(key, "")
                to_value = to_content.get(key, "")
                
                if key not in from_content:
                    added.append(f"Added section '{key}'")
                elif key not in to_content:
                    removed.append(f"Removed section '{key}'")
                elif from_value != to_value:
                    modified.append(f"Updated '{key}'")
            
            return {
                'added': added,
                'modified': modified,
                'removed': removed,
                'from_version': f"Version {from_version['version_number']}",
                'to_version': f"Version {to_version['version_number']}"
            }
            
        except Exception as e:
            raise e
        finally:
            if conn:
                conn.close()
    
    def get_latest_version(self, proposal_id: str) -> Optional[Dict[str, Any]]:
        """Get the latest version for a proposal"""
        conn = None
        try:
            conn = self.get_connection()
            cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            cur.execute("""
                SELECT id, proposal_id, version_number, content, created_by, created_at
                FROM proposal_versions 
                WHERE proposal_id = %s
                ORDER BY version_number DESC, created_at DESC
                LIMIT 1
            """, (proposal_id,))
            
            result = cur.fetchone()
            if not result:
                return None
            
            return {
                'id': str(result['id']),
                'proposal_id': str(result['proposal_id']),
                'version_number': result['version_number'],
                'content': result['content'],
                'created_by': str(result['created_by']) if result['created_by'] else None,
                'created_at': result['created_at'].isoformat()
            }
            
        except Exception as e:
            raise e
        finally:
            if conn:
                conn.close()
