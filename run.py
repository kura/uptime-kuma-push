#!/usr/bin/python3
import logging
import ssl
from collections import namedtuple
from multiprocessing import Pool
from os import getenv
from sys import exit
from time import monotonic, sleep
from urllib.request import urlopen


log_level = getenv("LOG_LEVEL", "info")
if log_level.lower() not in (
    "debug",
    "info",
    "warning",
    "error",
    "critical",
    "fatal",
):
    log_level = logging.INFO
    show_log_level_warning = True
else:
    show_log_level_warning = False
    log_level = getattr(logging, log_level.upper())

logger = logging.getLogger("enable-workflow")
handler = logging.StreamHandler()
formatter = logging.Formatter("%(asctime)s %(message)s")
handler.setFormatter(formatter)
logger.addHandler(handler)
logger.setLevel(log_level)


if show_log_level_warning:
    logger.warning(
        f"""Invalid LOG_LEVEL '{getenv("LOG_LEVEL")}', setting to 'info'"""
    )


push_url = getenv("PUSH_URL", None)
monitors = getenv("MONITORS", None)
if not push_url:
    logger.error("Missing PUSH_URL")
    exit(1)
if not monitors:
    logger.error("Missing MONITORS")
    exit(1)


Item = namedtuple("Item", ["name", "url", "token"])
try:
    items = [
        Item(*args)
        for args in [m.split("|") for m in monitors.split(",")]
    ]
except TypeError:
    logger.error("Invalid MONITORS format. Allowed format is \"[name|url|push_token][,name|url|push_token,...]\"")
    exit(1)

logger.info(f"Using PUSH_URL: {push_url}")
logger.info("Loaded the following monitors:")
for item in items:
    logger.info(f"Name: {item.name}, Url: {item.url}, Token: {item.token}")


def ping_and_push(item):
    try:
        req = urlopen(item.url, timeout=5, context=ssl._create_unverified_context())
        if req.status >= 200 and req.status <=300:
            for i in range(0, 5):
                logger.debug(f"'{item.name}' with URL '{item.url}' OK. Sending a ping")
                try:
                    urlopen(f"""{push_url.strip("/")}/{item.token}?status=up&msg=OK""", timeout=5)
                    break
                except:
                    logger.error(f"'{item.name}' error sending ping. Retrying", exc_info=True)
                    pass
    except Exception as e:
        logger.error(f"'{item.name}' with URL '{item.url}' error. Not sending a ping", exc_info=True)
        pass


while True:
    start = monotonic()
    with Pool(len(items)) as p:
        p.map(ping_and_push, items)
    end = monotonic()
    sleep_timer = max(10, 60 - (end - start))
    logger.info(f"Sleeping for: {sleep_timer}")
    sleep(sleep_timer)
