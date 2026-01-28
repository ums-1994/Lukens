"""psycopg2.extras shim"""

# Used as a sentinel in this project via: conn.cursor(cursor_factory=RealDictCursor)
class RealDictCursor:
    pass