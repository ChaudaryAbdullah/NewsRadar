"""
JWT + password utilities.
"""

import os
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional

from jose import JWTError, jwt
import bcrypt

SECRET_KEY  = os.getenv("JWT_SECRET", "newsradar-super-secret-change-in-prod-2024")
ALGORITHM   = "HS256"
ACCESS_EXPIRE_MINUTES = int(os.getenv("JWT_EXPIRE_MINUTES", "10080"))  # 7 days


def hash_password(plain: str) -> str:
    pwd_bytes = plain.encode('utf-8')
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(pwd_bytes, salt)
    return hashed.decode('utf-8')


def verify_password(plain: str, hashed: str) -> bool:
    pwd_bytes = plain.encode('utf-8')
    hashed_bytes = hashed.encode('utf-8')
    return bcrypt.checkpw(pwd_bytes, hashed_bytes)


def create_access_token(
    data: dict | str,
    expires_delta: Optional[timedelta] = None,
    expires_minutes: Optional[int] = None,
) -> str:
    """Create JWT token. Can pass dict or user_id string."""
    if isinstance(data, str):
        # If string is passed, assume it's user ID
        to_encode = {"sub": data}
    else:
        to_encode = data.copy()
    
    # Use expires_minutes if provided, otherwise expires_delta, otherwise default
    if expires_minutes:
        expire = datetime.now(timezone.utc) + timedelta(minutes=expires_minutes)
    elif expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire, "jti": str(uuid.uuid4())})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def decode_token(token: str) -> Optional[dict]:
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError:
        return None


def new_id(prefix: str = "usr") -> str:
    return f"{prefix}-{uuid.uuid4().hex[:8]}"
