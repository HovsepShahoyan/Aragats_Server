"""
Jetson Backend Client
Sends HTTP requests to Jetson FastAPI at 192.168.0.104:8000
"""
import requests
import logging
from django.conf import settings

logger = logging.getLogger('ptz')


class JetsonClient:
    def __init__(self):
        self.base_url = settings.JETSON_URL.rstrip('/')
        self.timeout = settings.JETSON_TIMEOUT

    def post(self, endpoint, data):
        url = f"{self.base_url}{endpoint}"
        try:
            logger.info(f"-> Jetson POST {endpoint}: {data}")
            resp = requests.post(url, json=data, timeout=self.timeout)
            resp.raise_for_status()
            result = resp.json()
            logger.info(f"<- Jetson: {result}")
            return result
        except requests.exceptions.ConnectionError:
            logger.error(f"Jetson offline: {self.base_url}")
            return {"error": "Jetson offline", "url": self.base_url}
        except requests.exceptions.Timeout:
            logger.error(f"Jetson timeout: {endpoint}")
            return {"error": "Jetson timeout"}
        except Exception as e:
            logger.error(f"Jetson error: {e}")
            return {"error": str(e)}

    def get(self, endpoint):
        url = f"{self.base_url}{endpoint}"
        try:
            logger.info(f"-> Jetson GET {endpoint}")
            resp = requests.get(url, timeout=self.timeout)
            resp.raise_for_status()
            result = resp.json()
            logger.info(f"<- Jetson: {result}")
            return result
        except requests.exceptions.ConnectionError:
            logger.error(f"Jetson offline: {self.base_url}")
            return {"error": "Jetson offline", "url": self.base_url}
        except requests.exceptions.Timeout:
            logger.error(f"Jetson timeout: {endpoint}")
            return {"error": "Jetson timeout"}
        except Exception as e:
            logger.error(f"Jetson error: {e}")
            return {"error": str(e)}

    def is_online(self):
        try:
            resp = requests.get(f"{self.base_url}/health", timeout=3)
            return {"online": True, "jetson_url": self.base_url, "health": resp.json()}
        except Exception:
            return {"online": False, "jetson_url": self.base_url}


jetson = JetsonClient()
