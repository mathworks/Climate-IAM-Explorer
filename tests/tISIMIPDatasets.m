classdef tISIMIPDatasets < matlab.mock.TestCase
    
    properties (Access = private)
        client
        Response = struct('count',1,'next',[],'previous', [], 'results', struct());
    end

    methods (TestClassSetup)

        function initializeClient(tc)
            
            [stubRestClient, restClientBehaviour] = createMock(tc, ...
                ?isimip.RESTClient, ConstructorInputs = {"https://data.isimip.org/api/v1","https://files.isimip.org/api/v1", [], []});

            tc.assignOutputsWhen(withAnyInputs(restClientBehaviour.get), ...
                tc.Response)
            
            tc.client = isimip.ISIMIPClient(restClient = stubRestClient);
        end

    end

    methods (Test, TestTags = {'ISIMIP'})

        function tSearchByDataset(tc)
            
            response = tc.client.dataset('10d11ba5-3157-485f-b7fa-062b30415354');
            tc.verifyEqual(response, tc.Response)

        end

        function tSearchByString(tc)

            response = tc.client.datasets(query='gfdl-esm4 ssp370 pr');
            tc.verifyEqual(response, tc.Response)

        end

        function tSearchBySubtree(tc)

            response = tc.client.datasets(tree='ISIMIP3b/InputData/climate/atmosphere/global/daily/ssp370/gfdl-esm4/r1i1p1f1/w5e5/pr');
            tc.verifyEqual(response, tc.Response)

        end

        function tSearchBySpecifiers(tc)

            response = tc.client.datasets(...
                simulation_round = "ISIMIP3b", ...
                product = "InputData", ...
                climate_forcing = "gfdl-esm4", ...
                climate_scenario = "ssp370", ...
                climate_variable = "pr");
            tc.verifyEqual(response, tc.Response)

        end

        function tCutoutAndDownload(tc)

            import matlab.unittest.fixtures.TemporaryFolderFixture
            
            tempFixture = tc.applyFixture(TemporaryFolderFixture);

            % to cut out a bounding box in lat/lon use
            % run this subsequently to poll the status
            path = 'ISIMIP3a/SecondaryInputData/climate/atmosphere/obsclim/global/daily/historical/CHELSA-W5E5v1.0/chelsa-w5e5v1.0_obsclim_tas_30arcsec_global_daily_201601.nc';
            response = tc.client.cutout(path, [-45.108, -41.935, 167.596, 173.644]);

            % once the status is 'finished', get the url to download the result
            tc.client.download(response.file_url, path=tempFixture.Folder + "/downloads", validate=false, extract=true);

            % this checking can be automated using poll=<time in seconds>
            response = tc.client.cutout(path, [-45.108, -41.935, 167.596, 173.644], poll=10);

            % plot the first timestep of the file
            path = fullfile(tempFixture.Folder, 'downloads' , 'chelsa-w5e5v1.0_obsclim_tas_30arcsec_lat-45.108to-41.935lon167.596to173.644_daily_201601.nc');
            
            x = ncread(path, 'lon');
            y = ncread(path, 'lat');
            z = ncread(path, 'tas');

            fig = figure();
            cleanupObj = onCleanup(@() delete(fig));

            imagesc( [x(1), x(end)], [y(1), y(end)], z(:,:,1));

        end

        function tMasks(tc)

            path = 'ISIMIP3b/InputData/climate/atmosphere/bias-adjusted/global/daily/ssp370/GFDL-ESM4/gfdl-esm4_r1i1p1f1_w5e5_ssp370_tas_global_daily_2015_2020.nc';
            response = tc.client.mask(path, country='nzl');
            paths = [
                "ISIMIP3b/InputData/climate/atmosphere/bias-adjusted/global/daily/ssp370/GFDL-ESM4/gfdl-esm4_r1i1p1f1_w5e5_ssp370_tas_global_daily_2015_2020.nc",
                "ISIMIP3b/InputData/climate/atmosphere/bias-adjusted/global/daily/ssp370/GFDL-ESM4/gfdl-esm4_r1i1p1f1_w5e5_ssp370_tas_global_daily_2021_2030.nc",
                "ISIMIP3b/InputData/climate/atmosphere/bias-adjusted/global/daily/ssp370/GFDL-ESM4/gfdl-esm4_r1i1p1f1_w5e5_ssp370_tas_global_daily_2031_2040.nc",
                "ISIMIP3b/InputData/climate/atmosphere/bias-adjusted/global/daily/ssp370/GFDL-ESM4/gfdl-esm4_r1i1p1f1_w5e5_ssp370_tas_global_daily_2041_2050.nc",
                "ISIMIP3b/InputData/climate/atmosphere/bias-adjusted/global/daily/ssp370/GFDL-ESM4/gfdl-esm4_r1i1p1f1_w5e5_ssp370_tas_global_daily_2051_2060.nc",
                "ISIMIP3b/InputData/climate/atmosphere/bias-adjusted/global/daily/ssp370/GFDL-ESM4/gfdl-esm4_r1i1p1f1_w5e5_ssp370_tas_global_daily_2061_2070.nc",
                "ISIMIP3b/InputData/climate/atmosphere/bias-adjusted/global/daily/ssp370/GFDL-ESM4/gfdl-esm4_r1i1p1f1_w5e5_ssp370_tas_global_daily_2071_2080.nc",
                "ISIMIP3b/InputData/climate/atmosphere/bias-adjusted/global/daily/ssp370/GFDL-ESM4/gfdl-esm4_r1i1p1f1_w5e5_ssp370_tas_global_daily_2081_2090.nc",
                "ISIMIP3b/InputData/climate/atmosphere/bias-adjusted/global/daily/ssp370/GFDL-ESM4/gfdl-esm4_r1i1p1f1_w5e5_ssp370_tas_global_daily_2091_2100.nc"
                ];
            response = tc.client.mask(paths, country='nzl');

        end
        
    end

    methods (Test, TestTags = {'Integration'})

        function tSelectPoints(tc)

            import matlab.unittest.fixtures.TemporaryFolderFixture
            
            tempFixture = tc.applyFixture(TemporaryFolderFixture);

            myclient = isimip.ISIMIPClient();
            response = myclient.datasets(...
                simulation_round='ISIMIP3b', ...
                           product='InputData', ...
                           climate_forcing='gfdl-esm4', ...
                           climate_scenario='ssp126', ...
                           climate_variable='sfcwind') ;

            file_paths = [];
            for dataset = response.results'

                for file = dataset.files'
                    file_paths = [file_paths; string(file.path)];
                end

            end

            lat = [52.518611; 40.712778; 39.906667; -23.5; -4.331667];
            lon = [13.408333; -74.005833;  116.3975; -46.616667; 15.313889];
            download_path = tempFixture.Folder + ["downloads/berlin"; "downloads/new-york-city"; "downloads/beijing"; "downloads/sao-paulo"; "downloads/kinshasa"];

            points = table(lat, lon, download_path);

            for i = 1:height(points)
                response = tc.client.select(file_paths, point=[points.lat(i), points.lon(i)], poll=10);
                tc.client.download(response.file_url, path = points.download_path(i), validate = false, extract= true);
            end
            
        end

    end

end