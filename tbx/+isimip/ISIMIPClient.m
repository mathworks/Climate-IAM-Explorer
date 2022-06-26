classdef ISIMIPClient

    properties (Access = private)
        restClient isimip.RESTClient
    end

    methods

        function obj = ISIMIPClient(nvp)

            arguments
                nvp.data_url      (1,1) string = "https://data.isimip.org/api/v1"
                nvp.files_api_url (1,1) string = "https://files.isimip.org/api/v1"
                nvp.auth = [];
                nvp.headers = {};
                nvp.restClient = isimip.RESTClient.empty();
            end

            if isempty(nvp.restClient)
                obj.restClient = isimip.RESTClient(nvp.data_url, nvp.files_api_url, nvp.auth, nvp.headers);
            else
                obj.restClient = nvp.restClient;
            end

        end

        function value = datasets(obj, varargin)

            value = obj.list("/datasets", varargin{:});

        end

        function value = countries(obj)

            value = obj.list("/countries");
            value = struct2table(value);
            value.key = string(value.key);
            value.long_name = string(value.long_name);

        end

        function value = glossary(obj, varargin)

            value = obj.list("/glossary", varargin{:});

        end

        function value = trees(obj, varargin)

            value = obj.list("/tree", varargin{:});
            value = struct2table(value);

            value.identifier = string(value.identifier);
            value.specifier = string(value.specifier);
            value.tree = string(value.tree);

        end

        function value = resources(obj, varargin)

            value = obj.list("/resources", varargin{:});

        end

        function value = facets(obj, varargin)

            value = obj.list("/facets", varargin{:});
            value = struct2table(value);
            value.title = string(value.title);
            value.attribute = string(value.attribute);

        end

        function value = dataset(obj, pk, varargin)

            value = obj.retrieve("/datasets", pk, varargin{:});

        end

        function value = files(obj, pk, varargin)

            value = obj.retrieve("/files", pk, varargin{:});

        end

        function value = file(obj, pk, varargin)
            value = obj.retrieve("/files", pk, varargin{:});
        end

        function download(obj, url, nvp)

            arguments
                obj
                url          (1,1) string
                nvp.path     (:,1) string  = string.empty();
                nvp.validate (1,1) logical = true;
                nvp.extract  (1,1) logical = true;
            end

            [~,file_name,file_ext] = fileparts(url);

            if isempty(nvp.path)
                out_path = pwd;
            else
                out_path = nvp.path;
            end
            file_path = fullfile(out_path, file_name + file_ext);

            if exist(nvp.path, 'dir') ~= 7
                mkdir(nvp.path)
            end

            websave(file_path, url);

            if nvp.validate

            end

            if file_ext == ".zip" && nvp.extract
                unzip(file_path, out_path)
                delete(file_path)
            end

        end

        function value = cutout(obj, paths, bbox, nvp)

            arguments
                obj
                paths string
                bbox
                nvp.poll = []
            end

            if numel(paths) == 1
                payload.paths = {paths};
            else
                payload = struct('paths', paths);
            end

            payload.task = 'cutout_bbox';
            payload.bbox = bbox;

            job = obj.restClient.postFiles(payload);

            if nvp.poll
                value = obj.poll(job, @(args) obj.cutout(args{:}), {paths, bbox, nvp.poll}, nvp.poll);
            else
                value = job;
            end

        end

        function value = select(obj, paths, nvp)

            arguments
                obj
                paths
                nvp.country = [];
                nvp.bbox = [];
                nvp.point = [];
                nvp.poll = [];
            end

            if numel(paths) == 1
                payload.paths = {paths};
            else
                payload = struct('paths', paths);
            end

            if ~isempty(nvp.country)
                payload.task = "select_country";
                payload.country = nvp.country;
            elseif ~isempty(nvp.bbox)
                payload.task = "select_bbox";
                payload.bbox = nvp.bbox;
            elseif ~isempty(nvp.point)
                payload.task = "select_point";
                payload.point = nvp.point;
            end

            job = obj.restClient.postFiles(payload);

            if ~isempty(nvp.poll)
                value = obj.poll(job, @(varargin) obj.select(varargin{1}, varargin{2:end}), {paths, nvp.country, nvp.bbox, nvp.point, nvp.poll}, nvp.poll);
            else
                value = job;
            end

        end

        function value = mask(obj, paths, nvp)

            arguments
                obj
                paths string
                nvp.country = [];
                nvp.bbox = [];
                nvp.landonly = [];
                nvp.poll = [];
            end

            if numel(paths) == 1
                payload.paths = {paths};
            else
                payload = struct('paths', paths);
            end


            if ~isempty(nvp.country)
                payload.task = "mask_country";
                payload.country = nvp.country;
            elseif ~isempty(nvp.bbox)
                payload.task = "mask_bbox";
                payload.bbox = nvp.bbox;
            elseif ~isempty(nvp.point)
                payload.task = "mask_landonly";
            end

            job  = obj.restClient.postFiles(payload);
            if nvp.poll
                value = obj.poll(job, @(varargin) obj.mask(varargin{1}, varargin{2:end}), {nvp.paths, nvp.country, nvp.bbox, nvp.landonly, nvp.poll}, nvp.poll);
            else
                value = job;
            end

        end

        function value = poll(obj, job, method, args, poll_sleep)

            disp("job " + job.id + ": " +job.status)
            if isfield(job, 'meta')
                disp(job.meta)
            end

            if ismember(job.status, ["queued", "started"])
                pause(poll_sleep)
                value = method(obj, args{:});
            else
                value = job;
            end

        end

    end

    methods (Access = private)

        function value = list(obj, resource_url, varargin)

            [url, unmatched] = obj.build_url(resource_url, [], varargin{:});
            value = obj.restClient.get(url, unmatched{:});

        end

        function value = retrieve(obj, resource_url, pk, varargin)

            url = obj.build_url(resource_url, pk, varargin{:});
            value = obj.restClient.get(url);

        end

        function value = create(obj, resource_url, data, varargin)

            url = obj.build_url(resource_url, [], varargin{:});
            value = obj.restClient.post(url, data);

        end

        function value = update(obj, resource_url, pk, data, varargin)

            url = obj.build_url(resource_url, pk, varargin{:});
            value = obj.restClient.put(url, data);

        end

        function value = destroy(obj, resource_url, varargin)

            url = obj.build_url(resource_url, pk, varargin{:});
            value = obj.restClient.delete(url, pk);

        end

        function [url, unmatched] = build_url(obj, resource_url, varargin)

            p = inputParser;
            p.KeepUnmatched = true;
            addRequired(p, 'resource_url')
            addRequired(p, 'pk')
            addParameter(p, 'list_route',   string.empty())
            addParameter(p, 'nested_route', string.empty())
            addParameter(p, 'detail_route', string.empty())

            p.parse(resource_url, varargin{:});
            unmatched =  namedargs2cell(p.Unmatched);


            resource_url = p.Results.resource_url;
            pk = p.Results.pk;

            url = strip(resource_url, 'right', '/')  + "/";

            if ~isempty(p.Results.list_route)
                url = url + strip(nvp.list_route, 'right', '/')  + "/";
            elseif ~isempty(p.Results.nested_route)
                url = url + nvp.parent_pk  + "/";
                url = url + strip(nvp.nested_route, 'right', '/')  + "/";
            end

            if ~isempty(pk)
                url = url + pk;
            end

            if ~isempty(p.Results.detail_route)
                url = url +  strip(nvp.detail_route, 'right', '/')  + "/";
            end

        end

    end

end
