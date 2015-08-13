from flask import jsonify, request
from flask import current_app, _request_ctx_stack
from app.exceptions import *
from couchbase.views.params import Query
from werkzeug.local import LocalProxy
from couchbase.n1ql import N1QLQuery
from . import blueprint
from pprint import pprint
from flask_jwt import jwt_required

@blueprint.before_request
def before_request():
    pprint('endpoint : ' + request.endpoint)
    # if request.endpoint != 'api_1_0.register':
    #     if not g.loginVerified:
    #         raise InvalidUsage('Forbidden', status_code=403)

@blueprint.route('/register', methods=['POST'])
def register():
    try:
        dataDict = request.get_json()
        print('start: ' + str(dataDict))
    except Exception as e:
        print 'ERROR: ' + str(e.__doc__) + ' ' + str(e.message)

    bucket = current_app.userBucket
    if not dataDict['username'] or not dataDict['password']:
        raise InvalidUsage('Invalid input', status_code=202)

    print('user/pass combination received ')
    # check if username already in use
    try:
        q = N1QLQuery('SELECT username FROM ' + current_app.config['CB_USERS_BUCKET'] + ' WHERE username = $username', username=dataDict['username'])
        results = bucket.n1ql_query(q)
        # print vars(results)
        for row in results:
            print row
            raise InvalidUsage('Username already used', status_code=409)
    except InvalidUsage as invalid:
        raise invalid
    except Exception as e:
        print 'ERROR : ' + str(e.__doc__) + ' ' + str(e.message)
        raise InvalidUsage('Internal server error', status_code=500)

    print "Username not used yet..create it in sync gateway."
    try:
        counter = bucket.counter(current_app.config['USER_COUNTER']).value
        key = str(counter)

        bucket.insert(key, {'username' : dataDict['username'] ,
                            'password': current_app.bcrypt.generate_password_hash(dataDict['password'])})

        retVal = jsonify(result='Success')
        print "user created."
        retVal.status_code = 201
        return retVal
    except Exception as e:
        print str(e)
        raise InvalidUsage('Error registering user', 500)


@blueprint.route('/updatePassword', methods=['PUT'])
@jwt_required()
def updatePassword():
    return None  #TODO: please implement me