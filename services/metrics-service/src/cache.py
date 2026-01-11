"""
Redis caching layer for metrics
"""

import json
from typing import Any
import redis.asyncio as redis
import structlog

from .config import settings

logger = structlog.get_logger()


class CacheManager:
    """Redis cache manager for metrics data"""

    def __init__(self):
        self.redis_client: redis.Redis | None = None

    async def connect(self):
        """Connect to Redis"""
        try:
            self.redis_client = await redis.from_url(
                settings.redis_url, encoding="utf-8", decode_responses=True
            )
            await self.redis_client.ping()
            logger.info("redis_connected", host=settings.REDIS_HOST)
        except Exception as e:
            logger.error("redis_connection_failed", error=str(e))
            raise

    async def disconnect(self):
        """Disconnect from Redis"""
        if self.redis_client:
            await self.redis_client.close()
            logger.info("redis_disconnected")

    async def get(self, key: str) -> Any | None:
        """
        Get value from cache

        Args:
            key: Cache key

        Returns:
            Cached value or None if not found
        """
        try:
            if not self.redis_client:
                return None

            value = await self.redis_client.get(key)
            if value:
                logger.debug("cache_hit", key=key)
                return json.loads(value)

            logger.debug("cache_miss", key=key)
            return None
        except Exception as e:
            logger.warning("cache_get_error", key=key, error=str(e))
            return None

    async def set(self, key: str, value: Any, ttl: int):
        """
        Set value in cache with TTL

        Args:
            key: Cache key
            value: Value to cache
            ttl: Time to live in seconds
        """
        try:
            if not self.redis_client:
                return

            await self.redis_client.setex(key, ttl, json.dumps(value))
            logger.debug("cache_set", key=key, ttl=ttl)
        except Exception as e:
            logger.warning("cache_set_error", key=key, error=str(e))

    async def delete(self, key: str):
        """
        Delete key from cache

        Args:
            key: Cache key to delete
        """
        try:
            if not self.redis_client:
                return

            await self.redis_client.delete(key)
            logger.debug("cache_delete", key=key)
        except Exception as e:
            logger.warning("cache_delete_error", key=key, error=str(e))

    async def clear_pattern(self, pattern: str):
        """
        Clear all keys matching pattern

        Args:
            pattern: Pattern to match (e.g., "metrics:tenant:*")
        """
        try:
            if not self.redis_client:
                return

            cursor = 0
            count = 0
            while True:
                cursor, keys = await self.redis_client.scan(cursor, match=pattern, count=100)
                if keys:
                    await self.redis_client.delete(*keys)
                    count += len(keys)
                if cursor == 0:
                    break

            logger.info("cache_pattern_cleared", pattern=pattern, count=count)
        except Exception as e:
            logger.warning("cache_clear_pattern_error", pattern=pattern, error=str(e))


# Global cache manager instance
cache = CacheManager()
