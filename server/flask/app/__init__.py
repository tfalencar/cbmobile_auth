from app.exceptions import InvalidUsage
from flask import Flask
from flask import jsonify
from couchbase.bucket import Bucket
from couchbase.exceptions import *
from . import exceptions
from flask_jwt import JWT
import os
import json
import requests
from pprint import pprint
from flask.ext.bcrypt import Bcrypt
from couchbase.n1ql import N1QLQuery
from datetime import datetime

from app.api_1_0 import blueprint as api

# configure according which machine we're running
module = __import__('config')
configuration = getattr(module, os.getenv('LOCAL_ENV', 'ProductionEnvironment'))

# Basic App initialization     ===============================================

app = Flask(__name__)
app.config.from_object(configuration)

app.appBucket = Bucket('couchbase://' + app.config['CB_HOST'] + '/' + app.config['CB_APP_BUCKET'])
app.userBucket = Bucket('couchbase://' + app.config['CB_HOST'] + '/' + app.config['CB_USERS_BUCKET'])

jwt = JWT(app)
app.bcrypt = Bcrypt(app)

# initialize JWT authentication  ======================================
@jwt.authentication_handler
def authenticate(username, password):
    #check if username already in use
    bucket = app.userBucket
    print '@authentication handler'
    user = []
    try:
        q = N1QLQuery('SELECT * FROM ' + app.config['CB_USERS_BUCKET'] + ' WHERE username = $user', user=username)
        results = bucket.n1ql_query(q)

        print vars(results)

        resultsCount = 0

        for row in results:
            resultsCount += 1
            user = row[app.config['CB_USERS_BUCKET']]
            pprint('The row: ' + str(row))
            if not app.bcrypt.check_password_hash(user['password'], password):
                raise InvalidUsage('Authentication failure', status_code=401)

        if resultsCount == 0:
            raise InvalidUsage('Authentication failure', status_code=401)

    except InvalidUsage as invalid:
        raise invalid
    except Exception as e:
        print 'ERROR : ' + str(e.__doc__) + ' ' + str(e.message)
        raise InvalidUsage('Internal server error', status_code=500)
    else:
        pprint('Authenticated ' + username)

        #create/fetch user's sync gateway session
        gatewayPath = app.config['SYNC_GATEWAY']

        #generate random password for sync gateway (client will use session token instead of gateway password)
        dt = datetime.now()
        dt.isoformat("T")
        time = dt.isoformat("T")
        hashedPwd = app.bcrypt.generate_password_hash(time)

        payload = {'name': username, 'password': hashedPwd}
        headers = {'content-type': 'application/json'}

        pprint("payload: " + str(json.dumps(payload)))
        pprint("to path: " + gatewayPath + "/_session")
        r = requests.post(gatewayPath + "/_session", data=str(json.dumps(payload)), headers=headers)

        pprint("sg status: " + str(r.status_code))
        pprint("sg response: " + str(r))
        pprint("sg Content: " + str(r.content))

        if r.status_code == 200:
            user['sg-session'] = r.content
        elif r.status_code == 404:
            print 'create user in sync gateway'
            r = requests.put(gatewayPath + "/_user/" + username, data=json.dumps(payload), headers=headers)
            pprint("status: " + str(r.status_code))
            pprint("Content: " + str(r.content))

            print 'get session from newly created user'
            r = requests.post(gatewayPath + "/_session", data=json.dumps(payload))

            pprint("status: " + str(r.status_code))
            pprint("Content: " + str(r.content))

            if r.status_code != 200:
                raise InvalidUsage('Authentication failure: ' + r.text, status_code=r.status_code)

            user['sg-session'] = r.content
        else:
            print 'SG error: ' + str(r)
            raise InvalidUsage('Internal server error', status_code=500)


    return user

@jwt.user_handler
def load_user(payload):
    print 'loading user..' + payload['username']
    try:
        bucket = app.userBucket
        q = N1QLQuery('SELECT * FROM ' + app.config['CB_USERS_BUCKET'] + ' WHERE username = $username', username=payload['username'])
        results = bucket.n1ql_query(q)
        for row in results:
            return row
        print '@jwt.user_handler: Unable to find user'
        return None
    except NotFoundError:
        print '@jwt.user_handler: Unable to load user'

@jwt.payload_handler
def make_payload(user):
    print type(user)
    return {
        'username': user['username'],
        'sg-session': user['sg-session'],
        'exp': (datetime.utcnow() + app.config['JWT_EXPIRATION_DELTA']).isoformat()
    }

@app.errorhandler(InvalidUsage)
def handle_invalid_usage(error):
    response = jsonify(error.to_dict())
    response.status_code = error.status_code
    return response

# on a first run, make sure to run the code below to initialize the count,
# otherwise you'll get errors:

# @app.before_first_request
# def create_user_counter():
# app.userBucket.insert(app.config['USER_COUNTER'], 0)
# app.userBucket.n1ql_query('CREATE PRIMARY INDEX ON ' + app.config['CB_USERS_BUCKET']).execute()


app.register_blueprint(api, url_prefix='/api/v1.0')

print('API initialization completed')
