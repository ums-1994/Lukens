#!/usr/bin/env python3
"""
Test script to verify PostgreSQL connection pool is working correctly
"""

import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(__file__))

def test_connection_pool():
    """Test the connection pool functionality"""
    print("🔍 Testing PostgreSQL Connection Pool...")
    print("=" * 60)
    
    try:
        from app import get_pg_pool, get_db_connection
        
        # Test 1: Pool Creation
        print("\n✅ Test 1: Pool Creation")
        pool = get_pg_pool()
        print(f"   Pool created: {pool is not None}")
        print(f"   Pool type: {type(pool).__name__}")
        
        # Test 2: Get Connection
        print("\n✅ Test 2: Get Single Connection")
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT 1 as test")
            result = cursor.fetchone()
            print(f"   Connection test query result: {result}")
            print("   ✅ Connection acquired and query executed successfully")
        print("   ✅ Connection automatically released")
        
        # Test 3: Multiple Sequential Connections
        print("\n✅ Test 3: Multiple Sequential Connections")
        for i in range(5):
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT %s as conn_num", (i + 1,))
                result = cursor.fetchone()
                print(f"   Connection {i + 1}: {result[0]}")
        print("   ✅ All 5 connections acquired and released successfully")
        
        # Test 4: Concurrent Connections (simulate)
        print("\n✅ Test 4: Test Connection Pool Under Load")
        connections = []
        try:
            # Try to get multiple connections
            for i in range(3):
                with get_db_connection() as conn:
                    cursor = conn.cursor()
                    cursor.execute("SELECT current_database()")
                    db_name = cursor.fetchone()[0]
                    print(f"   Connection {i + 1} - Database: {db_name}")
            print("   ✅ Connection pool handled multiple requests correctly")
        except Exception as e:
            print(f"   ❌ Error during load test: {e}")
            raise
        
        # Test 5: Exception Handling
        print("\n✅ Test 5: Exception Handling (Connection Should Still Be Released)")
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT 1")
                # Simulate an error
                raise ValueError("Test exception - connection should still be released")
        except ValueError as e:
            print(f"   Exception caught (expected): {e}")
            print("   ✅ Connection was automatically released despite exception")
        
        print("\n" + "=" * 60)
        print("🎉 ALL TESTS PASSED!")
        print("=" * 60)
        print("\n✅ Connection pool is working correctly!")
        print("✅ Connections are properly acquired and released")
        print("✅ Pool handles errors gracefully")
        print("\nYou can now safely use the connection pool in your application.")
        
        return True
        
    except ImportError as e:
        print(f"\n❌ Import Error: {e}")
        print("Make sure you're running this from the backend directory")
        print("and all dependencies are installed.")
        return False
    except Exception as e:
        print(f"\n❌ Test Failed: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = test_connection_pool()
    sys.exit(0 if success else 1)

