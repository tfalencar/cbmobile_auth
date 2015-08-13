# Define the application directory

import os
import datetime

# by setting an environment variable in your host its possible to
# automatically differentiate the environments and load configuration accordingly.
# See app/__init__.py

BASE_DIR = os.path.abspath(os.path.dirname(__file__))

class DefaultConfig(object):
    DEBUG = False
    TESTING = False
    CB_HOST = 'demo.com'  # replace with your couchbase server address
    CB_APP_BUCKET = 'demoapp'  # replace with your couchbase app bucket name
    CB_USERS_BUCKET = 'appusers'  # replace with your couchbase user's bucket name
    SYNC_GATEWAY = 'http://demo.com:4985/sync_gw_conektapp' # replace with your sync gateway url
    USER_COUNTER = 'user::count'  # document name for the user incremental count

    # Security
    SECRET_KEY = 'someUltraSecretThingy'
    # currently hardcoded value matches sync gateway's default session expiration. It is also
    # possible to modify the sync gateway's expiration time by adding the "expires" field when posting
    # to its _session endpoint
    JWT_EXPIRATION_DELTA = datetime.timedelta(seconds=24*3600)
    JWT_AUTH_URL_RULE = "/api/v1.0/auth"


class LocalDevelopmentConfig(DefaultConfig):
    # Statement for enabling the development environment
    DEBUG = True

class ProductionConfig(DefaultConfig):

    # Statement for enabling the development environment
    DEBUG = True

    # CB_HOST = 'localhost'
    # CB_APP_BUCKET = 'someOtherBuket'
    # CB_USERS_BUCKET = 'usersBucket'
    # SYNC_GATEWAY = 'http://localhost:4985/sync_gw_conektapp'
    # Database
