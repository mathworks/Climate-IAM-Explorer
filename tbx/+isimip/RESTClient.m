classdef RESTClient

    properties (SetAccess = private)
        Base_url (1,1) string
        Files_Api_Url (1,1) string
        Auth
        Headers
    end

    properties (Access = private)
        webopts
    end

    methods

        function obj = RESTClient(base_url, files_api_url, auth, headers)

            arguments
                base_url (1,1) string
                files_api_url (1,1) string
                auth    = [];
                headers = [];
            end

            obj.Base_url = base_url;
            obj.Files_Api_Url = files_api_url;
            obj.Auth = auth;
            obj.Headers = headers;

            obj.webopts = weboptions('HeaderFields', headers);

        end

        %     function response =  parse_response(obj, response):
        %         try:
        %             response.raise_for_status()
        %             return response.json()
        %         except requests.exceptions.HTTPError as e:
        %             print(response.content)
        %             raise e
        %
        function response = get(obj, url, varargin)

            response = webread(obj.Base_url + url, varargin{:}, obj.webopts);

        end

        function response = postFiles(obj, payload)

            response = webwrite(obj.Files_Api_Url, payload, obj.webopts);

        end

        function response = post(obj, url, data)

            response = webwrite(obj.Base_url + url, obj.webopts, data);

        end

        function response = put(obj, url, data)

            obj.webopts.RequestMethod = 'PUT';
            response = webwrite(obj.Base_url + url, data, obj.webopts);

        end

        function response = patch(obj, url, data)

            obj.webopts.RequestMethod = 'PATCH';
            response = requests.patch(obj.Base_url + url, data, obj.webopts);

        end

        function response = delete(obj, url)

            obj.webopts.RequestMethod = 'DELETE';
            response = webread(obj.Base_url + url);

        end

    end

end