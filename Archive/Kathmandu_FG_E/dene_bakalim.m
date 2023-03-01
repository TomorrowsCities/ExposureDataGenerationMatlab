clear;clc;

input_file_folder = 'C:\Kandilli Projects\tomorrow_cities\RandomAssignments\Codes\Kathmandu\';
% Read Landuse File
TV0_data_landuse = readtable( [ input_file_folder 'polygonsTV50.dbf'], "FileType","spreadsheet");

TV0_data_building = readtable( [ input_file_folder 'Building_Layer.xlsx'], "FileType","spreadsheet");

for zone_idx = 1: size(TV0_data_landuse,1) 
    zoneid = TV0_data_landuse.zoneID(zone_idx);
    total_zone_area = TV0_data_landuse.area(zone_idx)*10000; % hectare -> m2 (10000)
    temp_buildings_indx = [TV0_data_building.zoneID(:)].' ==zoneid;
    total_fpt_area = sum([TV0_data_building.fptarea(temp_buildings_indx)]);
    
    if total_fpt_area>total_zone_area
        disp(['ZoneID :' num2str(zoneid) ' Zone Area : ' num2str(total_zone_area), 'Total Fpt: ' num2str(total_fpt_area)] );
    end
end

%% Land use eger xlsx ise
clear;clc;
input_file_folder = 'C:\Kandilli Projects\tomorrow_cities\RandomAssignments\Codes\Kathmandu\Kathmandu_FG_E\';
% Read Landuse File
TV0_data_landuse = readtable( [ input_file_folder 'Landuse_layer.xlsx'], "FileType","spreadsheet");

TV0_data_building = readtable( [ input_file_folder 'Building_Layer.xlsx'], "FileType","spreadsheet");

for zone_idx = 1: size(TV0_data_landuse,1) 
    zoneid = TV0_data_landuse.zoneID(zone_idx);
    total_zone_area = TV0_data_landuse.area(zone_idx)*10000; % hectare -> m2 (10000)
    temp_buildings_indx = [TV0_data_building.zoneID(:)].' ==zoneid;
    total_fpt_area = sum([TV0_data_building.fptarea(temp_buildings_indx)]);
    
    if total_fpt_area>total_zone_area
        disp(['ZoneID :' num2str(zoneid) ' Zone Area : ' num2str(total_zone_area), 'Total Fpt: ' num2str(total_fpt_area)] );
    end
end






