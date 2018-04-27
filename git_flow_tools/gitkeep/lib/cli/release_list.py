from flask import request
from flask_restful import Resource
from marshmallow.exceptions import ValidationError

from app.extensions.json.json_api import JsonAPIException
from app.extensions.json.json_api import InvalidInputError
from app.releases.resources.release_schema import ReleaseSchema
from app.releases.models import ReleaseKind, ReleaseState

class ReleaseList(Resource):
    class ReleaseAlreadyExistsError(JsonAPIException):
        def __init__(self):
            super().__init__(status_code=412, title='Release already exists')

    def __init__(self, release_manager):
        self.release_manager = release_manager
        self.release_schema = ReleaseSchema()

    def get(self):
        """
        List all tracked releases
        ---
        tags:
          - manage
        parameters:
          - in: query
            name: limit
            required: false
            description: Limit the number of previous releases
            type: integer
        responses:
          200:
            description: Recent releases
            schema:
              type: array
              items:
                $ref: '#definitions/Release'
        """
        limit = request.args.get('limit', 10)
        releases = self.release_manager.latest_releases(limit)

        return self.release_schema.dump(releases, many=True)

    def post(self):
        """
        Track a new release
        ---
        tags:
          - manage
        parameters:
          - in: body
            name: new release
            schema:
              $ref: '#definitions/Release'
        responses:
          201:
            description: Tracked release
            schema:
              $ref: '#definitions/Release'
        """
        json_input = request.get_json() or {}
        try:
            release, errors = self.release_schema.load(json_input)
        except ValidationError as e:
            raise InvalidInputError(e.messages)

        if self.release_manager.release_for_version(release.version) is not None:
            raise ReleaseList.ReleaseAlreadyExistsError()

        self.release_manager.add_new_release(release)
        return self.release_schema.dump(release), 201
