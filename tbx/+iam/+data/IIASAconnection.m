classdef IIASAconnection < iam.data.Connection
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    properties (Dependent)
        Environment
    end
    
    properties
        DefaultRunsOnly (1,1) logical = true;
        Authorize (1,1) logical = false ;
    end
    
    properties (SetAccess = private)
        Config struct = struct( ...
            'name', {}, 'scheme', {}, 'env', {},'productName', {}, ...
            'uiUrl', {}, 'authUrl', {}, 'baseUrl', {}, 'database', {});
    end
    
    properties (Access = private)
        AuthToken
        AllEnvironments (:,5) table
    end
    
    properties (Constant, Access = private)
        Auth_Url (1,1) string = "https://db1.ene.iiasa.ac.at/EneAuth/config/v1";
    end
    
    methods
        
        function obj = IIASAconnection(varargin)
            
            p = inputParser();
            
            func = @(x) isstring(x) | ischar(x);
            
            addOptional(p,'env','',func)
            addOptional(p,'username','',func)
            addOptional(p,'password','',func)
            
            parse(p, varargin{:});
            
            % authenticate
            authenticateConnection(obj, p.Results.username, p.Results.password) ;
            
            % Constructor
            if obj.Authorize
                obj.getAllEnvironments(p.Results.env);
            else
                return
            end
            
        end
        
        function value = getEnvironments(obj)
            value = obj.AllEnvironments;
        end
        
        function value = getEnvironmentConfig(obj)
            value = obj.Config;
        end
        
    end
    
    methods %(Access = ?iam.IAMEnvironment)
        
        function value = getMetadata(obj)
            
            url = strjoin([obj.Config.baseUrl, "metadata/types"], "/");
            
            value = obj.getRequest(url);
            
            value = struct2table(value);
            
        end
        
        function value = getMetadataDetails(obj, category)
            
            url = strjoin([obj.Config.baseUrl, "metadata/types?name="], "/") + category + "";
            
            value = obj.getRequest(url);
        end
        
        function value = getDocumentation(obj, type, idx)
            
            url = strjoin([obj.Config.baseUrl, "docs"], "/");
            
            headerFields = {'Authorization', ['Bearer ', obj.AuthToken]; 'Content-Type', 'application/json'};
            options = weboptions('HeaderFields', headerFields, 'Timeout', 40);
            
            input = sprintf("{""keys"": [ ""/%s/%d""]}",type, idx);
            
            value = webwrite(url, input, options);
            
        end
        
        function data = getCurrentData(obj, varargin)
            data = obj.getBulkData('models',obj.Model, 'scenarios', obj.Scenario, varargin{:});
        end
        
        function data = getBulkData(obj, varargin)
            
            p = inputParser();
            
            func = @(x) isstring(x) | ischar(x);
            addParameter(p, 'runs', [], @isnumeric)
            addParameter(p, 'variables', '', func)
            addParameter(p, 'regions', '', func)
            addParameter(p, 'years', '', func)
            addParameter(p, 'units', '', func)
            addParameter(p, 'timeslices', '', func)
            
            parse(p, varargin{:});
            
            runNum = strjoin(string(num2str(p.Results.runs)),',');
            
            variable   = parseString(p.Results.variables);
            region     = parseString(p.Results.regions);
            years      = parseString(p.Results.years);
            units      = parseString(p.Results.units);
            timeslices = parseString(p.Results.timeslices);
            
            Url = obj.Config.baseUrl + "/runs/bulk/ts";
            
            input = "{""filters"": {""variables"": " + variable + ", ""runs"": [" + runNum + "], ""regions"":" + region + ", ""years"":" + years + ", ""units"": " + units + ", ""timeslices"": " + timeslices + "}}";
            
            response = obj.postRequest(Url, input);
            
            data = struct.empty();
            if ~isempty(response)
                tb = struct2table(response);
                
                vars = {'model', 'scenario', 'variable', 'region', 'unit'};
                
                current = 1;
                num = 1;
                data = struct([]);
                
                for i = 1 : height(tb)
                    
                    if i == height(tb) || ~isequal(tb(i, vars), tb(i+1, vars))
                        
                        data(num).model = string(tb.model{i});
                        data(num).scenario = string(tb.scenario{i});
                        data(num).variable = string(tb.variable{i});
                        data(num).region = string(tb.region{i});
                        data(num).unit = string(tb.unit{i});
                        data(num).runId = string(tb.runId(i));
                        data(num).version = string(tb.version(i));
                        data(num).years = tb.year(current:i);
                        data(num).values = timetable(datetime(tb.year(current:i),1,1,'Format', 'yyyy'), tb.value(current:i), ...
                            'DimensionNames', {'Year', 'VariableUnits'}, 'VariableNames', data(num).variable);
                        
                        num = num + 1;
                        current = i + 1;
                        
                    end
                    
                end
            end
            
            data = iam.IAMTimeseries(data);
            
            function value = parseString(str)
                
                if isempty(str)
                    value = "[]";
                else
                    str = string(str);
                    value = "[""" + strjoin(str,'","') + """]";
                end
                
            end
            
        end
        
        function response = getAllModels(obj)
            
            url = strjoin([obj.Config.baseUrl, "models"], "/");
            response = obj.getRequest(url);
            
            response = struct2table(response);
            
            if ~isempty(response)
                response.name = string(response.name);
            end
            
        end
        
        function response = getAllScenarios(obj)
            
            url = strjoin([obj.Config.baseUrl, "scenarios"], "/");
            
            response = obj.getRequest(url);
            
            response = struct2table(response);
            
            if ~isempty(response)
                response.name = string(response.name);
            end
            
        end
        
        function refs = getRefs(obj)
            
            
            url = obj.Config.baseUrl + "/runs/refs";
            refs = obj.getRequest(url);
            
            if ~isempty(refs)
                
                models = [refs.models{:}]';
                refs.models = toString(cell2table(models(2:end,:),'VariableNames',models(1,:)));
                
                scenarios = [refs.scenarios{:}]';
                refs.scenarios = toString(cell2table(scenarios(2:end,:),'VariableNames',scenarios(1,:)));
                
                variables = [refs.variables{:}]';
                refs.variables = toString(cell2table(variables(2:end,:),'VariableNames',variables(1,:)));
                
                regions = [refs.regions{:}]';
                refs.regions = toString(cell2table(regions(2:end,:),'VariableNames',regions(1,:)));
                
            end
            
        end
        
        function runs = getRunsList(obj)
            
            if obj.DefaultRunsOnly
                url = obj.Config.baseUrl + "/runs?getOnlyDefaultRuns=true&includeMetadata=true";
            else
                url = obj.Config.baseUrl + "/runs?getOnlyDefaultRuns=false&includeMetadata=true";
            end
            
            response = obj.getRequest(url);
            
            if ~isempty(response)
                runs = struct2table(response);
            end
            
        end
        
        function params = getRunDetails(obj, runId)
            
            if length(runId) == 1
                url = obj.Config.baseUrl + "/runs/" + runId + "/ts/iamvars";
                response = obj.getRequest(url);
                
                params = string({response.variable})';
            else
                
                runNum = strjoin(string(num2str(runId)),',');
                Url = obj.Config.baseUrl + "/runs/bulk/details";
                
                input = "{""filters"": {""variables"":[], ""runs"": [" + runNum + "], ""regions"":[], ""years"":[], ""units"":[], ""timeslices"":[]}}";
                params = obj.postRequest(Url, input);
                
            end
            
        end
        
    end
    
    methods % Accessors
        
        function set.Environment(obj, value)
            
            idx_name = matches(obj.AllEnvironments.name, value,'IgnoreCase',true);
            idx_productName = matches(obj.AllEnvironments.productName, value,'IgnoreCase',true);
            idx_env = matches(obj.AllEnvironments.env, value,'IgnoreCase',true);
            
            idx = idx_name | idx_productName | idx_env;
            
            if ~any(idx)
                error('iiasaConnection:invalidEnvironment', "This is not a valid environment, please select one of: " + strjoin(obj.AllEnvironments.env,', '))
            end
            
            if nnz(idx) > 1
               idx = find(idx, 1); 
            end
            
            obj.getEnvConfig( obj.AllEnvironments(idx, :) )
            
        end
        
        function value = get.Environment(obj)
            if isempty(obj.Config)
                value = "";
            else
                value = obj.Config.productName;
            end
        end
        
    end
    
    methods (Access = private)
        
        function authenticateConnection(obj, username, password)
            
            if isempty(username)
                obj.AuthToken = webread(strjoin([obj.Auth_Url, "anonym"],"/"));
                obj.Authorize = true ;
            elseif nargin == 3
                input = struct('username',username,'password',password) ;
                url = strjoin([obj.Auth_Url, "login"],"/");
                try
                    obj.AuthToken = obj.postRequest(url, input) ;
                    obj.Authorize = true ;
                catch
                    obj.Authorize = false ;
                    error("IIASAConnection:authenticateConnection:InvalidCredentials", ...
                        "Authentication failed, probably due to invalid credentials") ;
                end
                
            end
            
        end
        
        function getAllEnvironments(obj, environment)
            
            url = strjoin([obj.Auth_Url, "applications"], "/");
            names = obj.getRequest(url);
            
            numEnv = length(names);
            
            tb = table('Size',[numEnv,5],'VariableNames',{'productName','env','uiUrl','name','scheme'}, 'VariableTypes',{'string','string','string','string','string'});
            
            for i = 1 : length(names)
                name = names(i).name;
                scheme = names(i).scheme;
                if isfield(names(i), 'config')
                    con = names(i).config;
                    env = "env_" + i;
                    pname = "productName_" + i;
                    url = "URL_" + i;
                    for j = 1 : length(con)
                        switch con(j).path
                            case 'env'
                                env = genvarname(con(j).value);
                            case 'productName'
                                pname = con(j).value;
                            case 'uiUrl'
                                url = con(j).value;
                        end
                    end
                    
                    tb{i,:} = [string(pname), string(env), string(url), string(name), string(scheme)];
                end
            end
            
            obj.AllEnvironments = tb;
            
            if ~isempty(environment)
                obj.Environment = environment;
            end
            
        end
        
        function getEnvConfig(obj, env)
            
            url = strjoin([obj.Auth_Url, "config/user", env.name], "/");
            
            env_config = obj.getRequest(url);
            env_config = env_config.records;
            
            p = {env_config.path};
            sel = @(x) strcmp(x, p);
            obj.Config = struct(...
                'name', env.name, ...
                'scheme', env.scheme, ...
                'env', env.env, ...
                'productName', env.productName, ...
                'uiUrl', env.uiUrl, ...
                'authUrl', env_config(sel('authUrl')).value, ...
                'baseUrl', env_config(sel('baseUrl')).value, ...
                'database', env_config(sel('database')).value);
            try
                obj.Config.welcome = env_config(sel('welcomeMessage')).value;
            catch
                obj.Config.welcome = '';
            end
            
        end
        
        function response = postRequest(obj, url, input)
            
            import matlab.net.*;
            import matlab.net.http.*;
            import matlab.net.http.field.*;
            import matlab.net.http.io.*;
            
            mt = MediaType('application/json');
            
            mb = MessageBody();
            mb.Payload= unicode2native(input, 'UTF-8');
            hf1 = ContentTypeField(mt);
            hf2 = HeaderField('Authorization',['Bearer ', obj.AuthToken]);
            hf3 = AcceptField(mt);
            
            rm = RequestMessage('post', [hf1, hf2, hf3]);
            rm.Body = mb;
            
            rsp = rm.send(url);
            
            if rsp.StatusCode == "OK"
                response = rsp.Body.Data;
            else
                error('IIASAConnection:InvalidResponse', string(rsp.StartLine) + rsp.Body.Data)
            end
            
        end
        
        
        function res = getRequest(obj, url, varargin)
            
            headerFields = {'Authorization', ['Bearer ', obj.AuthToken]};
            options = weboptions('HeaderFields', headerFields, 'RequestMethod', 'get', 'MediaType', 'application/json', 'Timeout', 40, varargin{:});
            
            res = webread(url, options);
            
        end
        
    end
    
end

function tb = toString(tb)
% Transform cell arrays to string arrays for conveinence.
vars = tb.Properties.VariableNames;
for i = vars
    field = i{1};
    if iscellstr(tb.(field)) %#ok<ISCLSTR>
        tb.(field) = string(tb.(field));
    end
end

end