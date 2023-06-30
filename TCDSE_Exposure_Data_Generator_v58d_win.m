%% TCDSE Exposure Data Generator v5.8d

% INPUTS
% Land-use plan (polygon shapefile)
% Assumptions & distributions file (Excel File)
%
% OUTPUTS
% Land-use layer (xlsx)
% Building layer (xlsx / csv, in case total number of rows is greater than 2^20)
% Household layer (xlsx / csv, in case total number of rows is greater than 2^20)
% Individual layer (xlsx / csv, in case total number of rows is greater than 2^20)
% Building centres (point shapefile)
% Building footprints (polygon shapefile)
% Processing Report (txt)

%% License
 
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.

%% Part I

% Author  : Goktekin Durusoy
% E-mail  : goktekindurusoy@gmail.com
% Date    : 28 October 2022
% Version : 2 (updated as Version 3, 4 and 5 by Erdem Ozer lastly on 30 June 2023)

%% Part II

% Author  : Erdem Ozer 
% E-mail  : ozerer@gmail.com
% Date    : 04 March 2023
% Version : 8

%% Clear out the Workspace and Command Window
clear; clc; close all

%% Input File Folder
[luf_name,path_luf] = uigetfile('*.shp', 'Select Land-Use Shapefile');
disp(['Selected land-use file - ', fullfile(path_luf,luf_name)]);
info_luf_name = shapeinfo(fullfile(path_luf,luf_name));
prj_luf = info_luf_name.CoordinateReferenceSystem;
luf = shaperead(fullfile(path_luf,luf_name));
[luf_h, luf_w] = size(luf);

if isprop(info_luf_name.CoordinateReferenceSystem, 'ProjectionParameters')
    % do nothing
else % if land-use in GCS, convert PCS
    %utm_zone = utmzone(mean(info_luf_name.BoundingBox(:,2)),mean(info_luf_name.BoundingBox(:,1)));
    for i=1:luf_h
        [luf(i).X,luf(i).Y] = projfwd(projcrs(54034,'Authority','ESRI'),luf(i).Y,luf(i).X);
    end
    prj_luf = projcrs(54034,'Authority','ESRI');
end

for i = 1:luf_h
    polygon = polyshape(luf(i).X,luf(i).Y,'Simplify',false);
    luf(i).('area') = area(polygon)/10000;
end

[~, index] = sortrows([luf.zoneID].'); 
luf = luf(index);

TV0_data_landuse = struct2table(luf);

[dist_name,path_dist] = uigetfile('*.xlsx', 'Select Assumptions & Distributions Excel File');
disp(['Selected assumptions|distributions file - ', fullfile(path_dist,dist_name)]);
disp(' ')
dt_file = fullfile(path_dist,dist_name);

%profile on

%% PART I

% -------------------------------------------------------------------------
% STEP1
% -------------------------------------------------------------------------

wb = waitbar(0, 'Processing - Step 1', 'Name', 'Data Production');
tstrt = tic;

% user_percentage = 0.8; % 80% of the max available population will be generated
% max_new_population = (densityCap- population/zone_area) * zone_area; % Calculate max available population
% new_population = max_new_population*percantage; % Find out new population

% This step is not used exactly as it is because of the input landuse layer
% file. Therefore new population will be obtained by using without the area
% column in the Landuse layer dbf file. 

% For All Zone-IDs
area_ha = TV0_data_landuse.area;   % Area should be known
future_pop = round(TV0_data_landuse.densityCap.*area_ha);
nPeople = future_pop - TV0_data_landuse.population;

% for i = 1:length(nPeople)
%     if future_pop(i) ~= 0 && nPeople(i) < 0
%         msg = sprintf('Error for zoneID: %d\nExisting population: %d\nPopulation to be accommodated: %d\nTherefore, please either lower existing population or increase densityCap values!\n',...
%             TV0_data_landuse.zoneID(i),...
%             TV0_data_landuse.population(i),...
%             future_pop(i));
%         disp(msg)
%     end
% end

% for i = 1:length(nPeople)
%     if future_pop(i) ~= 0 && nPeople(i) < 0
%         warndlg('Please revise population(s) and/or densityCap value(s) for the mentioned zoneID(s)!','!!!ERROR!!!')
%         delete(wb)
%         %clearvars
%         return
%     end
% end

nPeople(nPeople < 0) = 0; % Negative populations become 0;

% -------------------------------------------------------------------------
% STEP2 Identify the number of households
% -------------------------------------------------------------------------

waitbar(2/26, wb, 'Processing - Step 2');

% Assumption : 
% Household size distribution is same for different income types

% Individuals in a household (Table-1)
% dist_table1 = [1   , 2, 3   , 4   , 5   , 6  , 7  , 8  , 9 ; ... % Number of individual in a household
%                22.4, 6, 11.3, 23.7, 14.9, 8.3, 3.2, 3.2, 7];     % Probability of having X people in a household (before dividing by the total number)

dist_table1 = readmatrix(dt_file,'Sheet','Distributions','Range','B8:P9');

%household_prop=dist_table1(2,:)/sum(dist_table1(2,:)); % The probability of X number of people living in a household
household_prop = dist_table1(2,:);
nHouse = round(nPeople /(sum(household_prop.*dist_table1(1,:)))); % Total number of households for all zones

% k=0;
% TV0_data_household =struct('hhID',[],'zoneID',[],'zoneType',[]);
% for zone_idx = 1:size(TV0_data_landuse,1) % For every zone in Landuse Layer
% %     if nHouse(zone_idx)==0
% %         disp(['there are no populations in the zone id: ' num2str(TV0_data_landuse.zoneID(zone_idx)) ] );
% %         continue;
% %     end
%     for i= 1:nHouse(zone_idx) 
%         k=k+1;
%         TV0_data_household(k,1).hhID = k; % Household Id
%         TV0_data_household(k,1).zoneID = TV0_data_landuse.zoneID(zone_idx); % Passive, keep it for future purposes
%         TV0_data_household(k,1).zoneType = TV0_data_landuse.avgIncome(zone_idx); % Passive, keep it for future purposes
%     end
% end

% accelerated solution
v = {'zoneID' 'avgIncome'};
v_to_use = v(ismember(v,TV0_data_landuse.Properties.VariableNames));
TV0_data_landuse_2 = TV0_data_landuse(:,v_to_use);
TV0_data_landuse_2 = renamevars(TV0_data_landuse_2,{'avgIncome'},{'zoneType'});

TV0_data_household = repelem(table2struct(TV0_data_landuse_2),nHouse);
hhID = num2cell(1:numel(TV0_data_household));
[TV0_data_household.hhID] = hhID{:};
zt = num2cell({TV0_data_household.zoneType});
[TV0_data_household.zoneType] = deal(zt{:});

% -------------------------------------------------------------------------
% STEP3 Identify the household size and assign "nInd" values to each household
% -------------------------------------------------------------------------

waitbar(3/26, wb, 'Processing - Step 3');

% Assumption : 
% Household size distribution is same for different income types

tv0dhzoneID = [TV0_data_household(:).zoneID];

TV0_data_household(1).nInd = []; % Initialize
% Do it for every zone
for zone_idx = 1:size(TV0_data_landuse,1) % For every zone in Landuse Layer
    if nHouse(zone_idx) == 0
        %disp(['there are no populations in the zone id: ' num2str(TV0_data_landuse.id(zone_idx)) ] );
        continue;
    end
    % Find Total of every different nInd number for households
    household_num = (nHouse(zone_idx) * household_prop);
    % Find the cumulative sum
    cumsum_household_num = round(cumsum(household_num,2));
    % Make it a column vector
    column_vector = cumsum2vector(cumsum_household_num);
    % Randomly permute the nInd
    sample_idx = randperm(length(column_vector));
    % Assign randomly permuted nInd into households
    temp_indx = tv0dhzoneID  == TV0_data_landuse.zoneID(zone_idx);
    temp_indx = temp_indx(:); % force it to be a column vector
    temp_numb = num2cell(column_vector(sample_idx));
    try
        [TV0_data_household(temp_indx).nInd] = deal(temp_numb{:});
    catch
        warndlg('Please check your input data!','!!!ERROR!!!')
        delete(wb)
        clearvars
        return
    end
end

% -------------------------------------------------------------------------
% STEP4 Identify and assign income type of the households
% -------------------------------------------------------------------------

waitbar(4/26, wb, 'Processing - Step 4');

avg_income_types = {'lowIncomeA','lowIncomeB','midIncome','highIncome'};

% Avg Income Dist. Tables (Table-2)
% Households  LIA   LIB  MI   HI
% dist_table2={[0.60 0.30 0.10 0   ];...       % LIA (Zone)
%              [0.35 0.50 0.15 0   ];...       % LIB (Zone)
%              [0.05 0.10 0.80 0.05];...       % MI  (Zone)
%              [0    0    0.15 0.85]};         % HI  (Zone)

dist_table2pri = readmatrix(dt_file,'Sheet','Distributions','Range','B14:E17');
dist_table2pri = dist_table2pri.';
dist_table2 = cell(size(dist_table2pri,2), 1);
for ii = 1:size(dist_table2,1)
    dist_table2{ii,1} = dist_table2pri(:, ii).';
end

tv0dhzoneType = [TV0_data_household(:).zoneType];

TV0_data_household(1).income_numb = []; % Initialize ( keep it as a number 1-lowIncomeA, 2-lowIncomeB, 3-midIncome, 4-highIncome
TV0_data_household(1).income = []; % Initialize
for i = 1: length(avg_income_types)
    % Get total number of households wrt income type of zone.
    income_idx = strcmp(tv0dhzoneType, avg_income_types{i});
    income_idx = income_idx(:); % force it to be a column vector
    % Find Total of every different income type
    income_of_households = dist_table2{i}*sum(income_idx);
    % Find the cumulative sum  
    cumsum_household_num = round(cumsum(income_of_households));
    % Make it a column vector
    column_vector = cumsum2vector(cumsum_household_num);
    % Randomly permute the average income types
    sample_idx = randperm(length(column_vector));
    % Assign randomly permuted average income types into households
    temp_numb = num2cell(column_vector(sample_idx));
    temp_str = avg_income_types(column_vector(sample_idx));    
    [TV0_data_household(income_idx).income_numb] = deal(temp_numb{:});
    [TV0_data_household(income_idx).income] = deal(temp_str{:});
end

% -------------------------------------------------------------------------
% STEP5 Identify and assign a unique ID for each  individual
% -------------------------------------------------------------------------

waitbar(5/26, wb, 'Processing - Step 5');

TV0_data_individual = cell2table(cell(0,1), 'VariableNames', {'indivID'});
TV0_data_individual.indivID(:,1) = (1:sum([TV0_data_household.nInd]));
TV0_data_individual = table2struct(TV0_data_individual);
TV0_data_individual(1).('hhID') = [];

% TV0_data_individual =struct('hhID',[],'indivId',[]);
% k=0;
% 
% for hh_idx = 1:size(TV0_data_household,1) % For every household in Household Layer    
%     for i= 1:TV0_data_household(hh_idx).nInd     
%         k=k+1;
%         TV0_data_individual(k,1).indivId = k; % Individual Id               
%     end
% end

% -------------------------------------------------------------------------
% STEP6 Identify and assign gender for each individual
% -------------------------------------------------------------------------

waitbar(6/26, wb, 'Processing - Step 6');

% Assumption :
% Gender distribution is same for different income types 

% Gender (Meta Data)
% 1 - Female
% 2 - Male

% Gender Dist. Table (Table-3)
%            F   M 
% dist_table3=[0.5 0.5];

dist_table3 = readmatrix(dt_file,'Sheet','Distributions','Range','B22:C22');

TV0_data_individual(1).gender = []; % Initialize
n_total_people = size(TV0_data_individual,1);
% Find Total number of individuals of different gender
gender_of_individuals=dist_table3*n_total_people;
% Find the cumulative sum  
cumsum_gender_num = round(cumsum(gender_of_individuals));
% Make it a column vector
column_vector = cumsum2vector(cumsum_gender_num);
% Randomly permute the gender on individuals
sample_idx = randperm(length(column_vector));
% Assign randomly permuted gender types into individuals
temp_numb = num2cell(column_vector(sample_idx));    
[TV0_data_individual(:).gender] = deal(temp_numb{:}); 

% -------------------------------------------------------------------------
% STEP7 Identify and assign age for each individual
% -------------------------------------------------------------------------

waitbar(7/26, wb, 'Processing - Step 7');

% Assumption :
% Age profile is same for different income types

% Age Profile (Meta Data)
% AP1 - 01-04  
% AP2 - 05-09  
% AP3 - 10-14  
% AP4 - 14-19  
% AP5 - 20-24  
% AP6 - 25-29
% AP7 - 30-39
% AP8 - 40-49  
% AP9 - 50-64  
% AP10- 65+   	
%
% Age Profile with respect to gender (taken from Turkish Statistical Institute )
%   | AP1  | AP2  | AP3  | AP4  | AP5  | AP6  | AP7  | AP8  | AP9  | AP10 |
% F |0.0664|0.1533|0.0420|0.0321|0.0778|0.0768|0.1488|0.1451|0.1588|0.0989|
% M |0.0664|0.1533|0.0420|0.0321|0.0778|0.0768|0.1488|0.1451|0.1588|0.0989|

% dist_table4 = {[0.0664 0.1533 0.0420 0.0321 0.0778 0.0768 0.1488 0.1451 0.1588 0.0989];... % Female
%                [0.0664 0.1533 0.0420 0.0321 0.0778 0.0768 0.1488 0.1451 0.1588 0.0989]};   % Male

dist_table4pri = readmatrix(dt_file,'Sheet','Distributions','Range','B33:K34');
dist_table4pri = dist_table4pri.';
dist_table4 = cell(size(dist_table4pri,2), 1);
for ii = 1:size(dist_table4,1)
    dist_table4{ii,1} = dist_table4pri(:, ii).';
end

age_intervals = readmatrix(dt_file,'Sheet','Distributions','Range','B32:K32');

TV0_data_individual(1).age = []; % Initialize
for gender_id = 1:2
    % Get total number of individuals wrt gender.
    gender_idx = [TV0_data_individual(:).gender] == gender_id;
    gender_idx = gender_idx(:); % force it to be a column vector
    % Find Total number of individuals for different age
    age_of_individuals = dist_table4{gender_id}*sum(gender_idx);
    % Find the cumulative sum  
    cumsum_age_num = round(cumsum(age_of_individuals));
    % Make it a column vector
    column_vector = cumsum2vector(cumsum_age_num);
    % Randomly permute the age profiles of individuals
    sample_idx = randperm(length(column_vector));
    % Assign randomly permuted age profiles into individuals
    temp_numb = num2cell(column_vector(sample_idx));   
    [TV0_data_individual(gender_idx).age] = deal(temp_numb{:}); 
end

tv0diage = [TV0_data_individual(:).age].';
for jj = 1:size(tv0diage,1)
    if tv0diage(jj) == 1
        tv0diage(jj) = randi([age_intervals(1) age_intervals(2)-1]);
    elseif tv0diage(jj) == 2
        tv0diage(jj) = randi([age_intervals(2) age_intervals(3)-1]);
    elseif tv0diage(jj) == 3
        tv0diage(jj) = randi([age_intervals(3) age_intervals(4)-1]);
    elseif tv0diage(jj) == 4
        tv0diage(jj) = randi([age_intervals(4) age_intervals(5)-1]);
    elseif tv0diage(jj) == 5
        tv0diage(jj) = randi([age_intervals(5) age_intervals(6)-1]);
    elseif tv0diage(jj) == 6
        tv0diage(jj) = randi([age_intervals(6) age_intervals(7)-1]);
    elseif tv0diage(jj) == 7
        tv0diage(jj) = randi([age_intervals(7) age_intervals(8)-1]);
    elseif tv0diage(jj) == 8
        tv0diage(jj) = randi([age_intervals(8) age_intervals(9)-1]);
    elseif tv0diage(jj) == 9
        tv0diage(jj) = randi([age_intervals(9) age_intervals(10)-1]);
    elseif tv0diage(jj) == 10
        tv0diage(jj) = randi([age_intervals(10) 90]);
    else
        tv0diage(jj) = randi([age_intervals(1) 90]);
    end
end

tv0diagecell = num2cell(tv0diage)';
[TV0_data_individual.age] = tv0diagecell{:};

% -------------------------------------------------------------------------
% STEP8 Identify and assign education attainment status for each individual
% -------------------------------------------------------------------------

waitbar(8/26, wb, 'Processing - Step 8');

% Assumption :
% Education Attainment status is same for different income types 

% Education Attainment Status (Meta Data)
% 1 - Only literate
% 2 - Primary school
% 3 - Elementary sch.
% 4 - High school
% 5 - University and above

% dist_table5 = {[0.05 0.140 0.1510 0.1880 0.4710];... % Female
%                [0.05 0.165 0.1606 0.1040 0.5204]};   % Male

dist_table5pri = readmatrix(dt_file,'Sheet','Distributions','Range','B45:F46');
dist_table5pri = dist_table5pri.';
dist_table5 = cell(size(dist_table5pri,2), 1);
for ii = 1:size(dist_table5,1)
    dist_table5{ii,1} = dist_table5pri(:, ii).';
end

TV0_data_individual(1).eduAttStat = []; % Initialize
for gender_id = 1:2
    % Get total number of individuals wrt gender.
    gender_idx = [TV0_data_individual(:).gender] == gender_id;
    gender_idx = gender_idx(:); % force it to be a column vector
    % Find Total number of individuals for different eduAttStat
    eduattstatus_of_individuals = dist_table5{gender_id}*sum(gender_idx);
    % Find the cumulative sum  
    cumsum_edu_num = round(cumsum(eduattstatus_of_individuals));
    % Make it a column vector
    column_vector = cumsum2vector(cumsum_edu_num);
    % Randomly permute the education attainment status
    sample_idx = randperm(length(column_vector));
    % Assign randomly permuted education attainment status into individuals
    temp_numb = num2cell(column_vector(sample_idx));   
    [TV0_data_individual(gender_idx).eduAttStat] = deal(temp_numb{:}); 
end

% -------------------------------------------------------------------------
% STEP9 Identify and assign the head of household to corresponding hhID
% -------------------------------------------------------------------------

waitbar(9/26, wb, 'Processing - Step 9');

% Assumption :
% Head of household is dependent to gender 
% Only (age>x) can be head of households

% Head of Household
% dist_table6= [0.23;  % Female
%               0.77]; % Male

dist_table6 = readmatrix(dt_file,'Sheet','Distributions','Range','B27:C27').';

[TV0_data_individual(:).head] = deal(0); % Initialize

try 
    % Number of  household head 
    n_headofhousehold = size(TV0_data_household,1);
    total_cumsum=round(cumsum(dist_table6*n_headofhousehold)); % Total female household head, and male household head
    % Make it a column vector
    column_vector = cumsum2vector(total_cumsum); 
    % Randomly permute the gender of household heads
    sample_idx = randperm(length(column_vector));
    
    % Assign randomly permuted household heads into temporary location
    temp_numb = column_vector(sample_idx);   
    male_head_household_numb = sum(temp_numb==2); % total number of households with male household head
    female_head_household_numb = sum(temp_numb==1); % total number of households with female household head
    age_indx = [TV0_data_individual(:).age] >= readmatrix(dt_file,'Sheet','Assumptions','Range','C18:C18'); % Find individuals with age equal to or bigger than x
    
    % Find out possible candidates between males and assign
    gender_male_indx = [TV0_data_individual(:).gender]==2; % 2 means male
    possible_male_indx = and(age_indx,gender_male_indx);
    possible_male_numb = sum(possible_male_indx);
    male_indices = find(possible_male_indx);
    rand_index_male = randperm(possible_male_numb,male_head_household_numb);
    head_male_ind = male_indices(rand_index_male);
    [TV0_data_individual(head_male_ind).head] = deal(1);
    temp_hhid = num2cell([TV0_data_household(temp_numb==2).hhID]);
    [TV0_data_individual(head_male_ind(:)).hhID] =deal(temp_hhid{:});
    
    % Find out possible candidates between females and assign
    gender_male_indx = [TV0_data_individual(:).gender]==1; % 1 means female
    possible_female_indx = and(age_indx,gender_male_indx);
    possible_female_numb = sum(possible_female_indx);
    female_indices = find(possible_female_indx);
    rand_index_male = randperm(possible_female_numb,female_head_household_numb);
    head_female_ind = female_indices(rand_index_male);
    [TV0_data_individual(head_female_ind).head] = deal(1);
    temp_hhid = num2cell([TV0_data_household(temp_numb==1).hhID]);
    [TV0_data_individual(head_female_ind(:)).hhID] =deal(temp_hhid{:});
catch
    warndlg('Please update your Distibution Table 3 and/or 6 to provide a logical request!','!!!ERROR!!!')
    delete(wb)
    clearvars
    return
end

% -------------------------------------------------------------------------
% STEP10 Identify and assign the household that each individual belongs to
% (others than head of households)
% -------------------------------------------------------------------------

waitbar(10/26, wb, 'Processing - Step 10');

% Assumption :
% In relation with Assumption in Step 9, no individuals under 20 years of
% age can live alone in an household.

empty_hhid_individuals_idx = cellfun(@isempty, {TV0_data_individual(:).hhID}.');
possible_individuals = find(empty_hhid_individuals_idx);

% for i = 1: size(TV0_data_household,1)
%     individual_numb = TV0_data_household(i).nInd;
%     if individual_numb>1
%         % Find out possible candidates and assign
%         countx = size(possible_individuals,1);
%         rand_index_hhid = randperm(countx,individual_numb-1);
%         [TV0_data_individual(possible_individuals(rand_index_hhid)).hhID] = deal(TV0_data_household(i).hhID);
%         possible_individuals = removerows(possible_individuals,'ind',rand_index_hhid);
%     end
% end

% accelerated solution
TV0_data_household([TV0_data_household.nInd] < 1) = [];
hhID_pool = repelem([TV0_data_household.hhID], [TV0_data_household.nInd]-1);
Nmatch = min(numel(possible_individuals), numel(hhID_pool));
hhID_pool = num2cell(hhID_pool(1:Nmatch));
locations = randperm(numel(possible_individuals), Nmatch);
[TV0_data_individual(possible_individuals(locations)).hhID] = deal(hhID_pool{:});

% -------------------------------------------------------------------------
% STEP10a Identify school enrollment for each individual
% -------------------------------------------------------------------------

% Assumption :
% Schooling age limits : AP2 and AP3 can go to school
% School Enrollment
%                EA1|EA2|EA3|EA4|EA5
% dist_table5a = {[0.7 0.7 0.7 0.8 0.8];...   % lowIncome
%                 [0.7 0.8 0.8 0.9 1.0];...   % midIncome
%                 [0.8 0.9 1.0 1.0 1.0]};     % highIncome

dist_table5apri = readmatrix(dt_file,'Sheet','Distributions','Range','B51:F53');
dist_table5apri = dist_table5apri.';
dist_table5a = cell(size(dist_table5apri,2), 1);
for ii = 1:size(dist_table5a,1)
    dist_table5a{ii,1} = dist_table5apri(:, ii).';
end

schoolEnrollment = -1*ones(size(TV0_data_individual,1),1); % assign all schoolenrollment to -1 for initialization

age_indx_total = and([TV0_data_individual(:).age] >= readmatrix(dt_file,'Sheet','Assumptions','Range','C66:C66'), ...
    [TV0_data_individual(:).age] <= readmatrix(dt_file,'Sheet','Assumptions','Range','D66:D66')); % Find individuals having ages between x-y
age_indx_total = age_indx_total(:); % Force to be a column vector
indivID_ofstudents = find(age_indx_total); % individual Id of students
hhID_ofstudents = [TV0_data_individual(age_indx_total).hhID].'; % household Id of students
head_eduattstat = zeros(size(hhID_ofstudents,1),1); % Initialize
%income_type = zeros(size(hhID_ofstudents,1),1); % Initialize

% for i=1:length(hhID_ofstudents)    
%     temp_hhid = hhID_ofstudents(i); % temporary household id of students
%     hh_id_index = tv0dihhid == temp_hhid; % Individual indx of temporary household id 
%     temp_indiv = TV0_data_individual(hh_id_index);  % Individuals in same household
%     head_eduattstat(i,1)=temp_indiv([TV0_data_individual(hh_id_index).head].'==1).eduAttStat; % eduAtt status of head of household
%     if isempty(TV0_data_household(tv0dhhhid==temp_hhid).income_numb)
%         income_type (i) = randi([1 3]);
%     else
%         income_type (i) = TV0_data_household(tv0dhhhid==temp_hhid).income_numb; % income type of household
%     end
% end

% accelerated solution
tv0dihead = [TV0_data_individual.head].' == 1;
tv0dieduAS = [TV0_data_individual.eduAttStat];

[~, idx] = ismember(hhID_ofstudents, [TV0_data_household.hhID].');
[temp1, temp1_idx] = sort([TV0_data_individual.hhID].');
temp2 = tv0dihead(temp1_idx);
temp3 = tv0dieduAS(temp1_idx);
array2 = zeros(size(hhID_ofstudents, 1),1);
for i = 1:length(hhID_ofstudents)
    hid = ismembc2(hhID_ofstudents(i), temp1);
    while ~temp2(hid)
       hid = hid - 1;
    end
    head_eduattstat(i) = temp3(hid);
end

temp4 = [TV0_data_household.income_numb];
income_type = temp4(idx)';

% Combine all info
%                    |Household id    |Individual ID    |EduAttStat of Head |Income of Household
total_student_info = [hhID_ofstudents, indivID_ofstudents, head_eduattstat, income_type]; 

for income_indx = 1 : 3 % For all income type, table have only 3 LowIncome, MidIncome ,HighIncome
    for edu_indx = 1 : 5 % For all EduAttStat
        get_table = dist_table5a{income_indx};
        school_enrollment = get_table(edu_indx);
        school_prob = [1-school_enrollment , school_enrollment]; % Get school probablity, 
        if income_indx==1
            indx_students = and(or(total_student_info(:,4)==income_indx, total_student_info(:,4)==income_indx+1),head_eduattstat==edu_indx); % Find index of students related with eduattstat of head, and income type           
        else
            indx_students = and(total_student_info(:,4)==income_indx+1,head_eduattstat==edu_indx); % +1 is used to obtain 3,4 which are mid income and high income 
        end
        indx_students = indx_students(:); % force it to be a column vector
        if sum(indx_students)==0
            continue;
        end
        % Find Total number of individuals wrt edu indx and income indx
        schoolstatus_of_individuals = school_prob*sum(indx_students);
        % Find the cumulative sum  
        cumsum_school_num = round(cumsum(schoolstatus_of_individuals));
        % Make it a column vector
        column_vector = cumsum2vector(cumsum_school_num)-1; % To force it 0 and 1, 0 not going, 1 going to school        
        % Randomly permute the school status
        sample_idx = randperm(length(column_vector));
        % Assign randomly permuted school status into individuals         
        total_student_info(indx_students,5) = column_vector(sample_idx);
    end
end
[TV0_data_individual(:).schoolEnrollment] = deal(-1); % assign all schoolenrollment to -1 for initialization
temp_school_enroll = num2cell(total_student_info(:,5));
[TV0_data_individual(total_student_info(:,2)).schoolEnrollment] = deal(temp_school_enroll{:}); % Assign schoolenrollment to individuals

% -------------------------------------------------------------------------
% STEP11 Identify total residential building area
% -------------------------------------------------------------------------

waitbar(11/26, wb, 'Processing - Step 11');

% Average dwelling area (sqm) wrt income type (44 for LI, 54 for MI, 67 for HI in Tomorrovwille)
% Range of footprint area (sqm) wrt. Income type (32-66 for LI, 32-78 for MI and 70-132 for HI in Tomorrowville)

% 
%                         LIA LIB MI HI
%Average_dwelling_area = [44  44  54 67];
Average_dwelling_area = readmatrix(dt_file,'Sheet','Assumptions','Range','C31:F31');
totalbldarea_res = zeros (size(TV0_data_landuse,1),1); % Initialize

tv0dhzoneID = [TV0_data_household(:).zoneID].';

for zone_idx = 1:size(TV0_data_landuse,1)
    zoneid = TV0_data_landuse.zoneID(zone_idx);
    if nHouse(zone_idx)==0
        continue;
    end 
    income_type_households = [TV0_data_household(tv0dhzoneID == zoneid).income_numb].' ; % Income type of specific zoneID 
    totalbldarea_res(zone_idx) = sum(Average_dwelling_area(income_type_households)); % Keep it for future purposes.
end

% -------------------------------------------------------------------------
% STEP12 Identify number of residential buildings and generate building layer
% -------------------------------------------------------------------------

waitbar(12/26, wb, 'Processing - Step 12');

% Assumptions : 
% Average dwelling area (sqm) wrt income type (44 for LI, 54 for MI, 67 for HI in Tomorrovwille)
% Range of footprint area (sqm) wrt. Income type (32-66 for LI, 32-78 for MI and 70-132 for HI in Tomorrowville)
% fpt_area = {[32 66];... % lowIncomeA
%             [32 66];... % lowIncomeB
%             [32 78];... % midIncome
%             [70 132]};  % highIncome

fpt_area_pri = readmatrix(dt_file,'Sheet','Assumptions','Range','C23:D26');
fpt_area_pri = fpt_area_pri.';
fpt_area = cell(size(fpt_area_pri,2), 1);
for ii = 1:size(fpt_area,1)
    fpt_area{ii,1} = fpt_area_pri(:, ii).';
end

% Land Use Type 
% 1 - {'AGRICULTURE'                     }
% 2 - {'CITY CENTER'                     }
% 3 - {'COMMERCIAL AND RESIDENTIAL'      }
% 4 - {'HISTORICAL PRESERVATION AREA'    }
% 5 - {'INDUSTRY'                        }
% 6 - {'NEW DEVELOPMENT'                 }
% 7 - {'NEW PLANNING'                    }
% 8 - {'RECREATION AREA'                 }
% 9 - {'RESIDENTIAL (GATED NEIGHBORHOOD)'}
% 10- {'RESIDENTIAL (HIGH DENSITY)'      }
% 11- {'RESIDENTIAL (LOW DENSITY)'       }
% 12- {'RESIDENTIAL (MODERATE DENSITY)'  }

%land_use_types = unique(TV0_data_landuse.LuF);

% ttt1 = table(TV0_data_landuse.LuF, TV0_data_landuse.densityCap, TV0_data_landuse.LuF,TV0_data_landuse.avgIncome);
% ttt2 = unique(ttt1,'stable');
% land_use_types = table2struct(ttt2);

land_use_types = TV0_data_landuse.LuF;

% Number of storeys
% LR - 1-4  storeys	Low Rise	
% MR - 5-8  storeys	Mid Rise	
% HR - 9-19 storeys	High Rise	

% LRS Types
% 1-BrCfl: brick and cement with flexible floor;		
% 2-BrCri: brick and cement with rigid floor;		
% 3-BrM: brick and mud		
% 4-Adb: Adobe		
% 5-RCi : Reinforced Concrete infill		
% lrs_types = {'BrCfl','BrCri','BrM','Adb','RCi'};

lrs_types = readcell(dt_file,'Sheet','Distributions_T8','Range','B9:B23').';

storey_info = readmatrix(dt_file,'Sheet','Distributions_T7','Range','B9:C11');

%              |   LRS1    |    LRS2     |    LRS3     |    LRS4     |    LRS5     |
%              |LR | MR| HR|  LR | MR| HR|  LR | MR| HR|  LR| MR | HR|  LR| MR|  HR|
% dist_table7 = {[0.2 0.6 0.2],[0.2 0.6 0.2],[0.2 0.6 0.2],[0.8 0.2 0.0],[0.2 0.6 0.2];...    % LUT1 
%                [0.2 0.6 0.2],[0.2 0.6 0.2],[0.2 0.6 0.2],[0.8 0.2 0.0],[0.2 0.6 0.2];...    % LUT2 
%                [0.2 0.6 0.2],[0.2 0.6 0.2],[0.2 0.6 0.2],[0.8 0.2 0.0],[0.2 0.6 0.2];...    % LUT3 
%                [0.2 0.6 0.2],[0.2 0.6 0.2],[0.2 0.6 0.2],[0.8 0.2 0.0],[0.2 0.6 0.2];...    % LUT4 
%                [0.2 0.6 0.2],[0.2 0.6 0.2],[0.2 0.6 0.2],[0.8 0.2 0.0],[0.2 0.6 0.2];...    % LUT5 
%                [0.2 0.6 0.2],[0.2 0.6 0.2],[0.2 0.6 0.2],[0.8 0.2 0.0],[0.2 0.6 0.2];...    % LUT6 
%                [0.2 0.6 0.2],[0.2 0.6 0.2],[0.2 0.6 0.2],[0.8 0.2 0.0],[0.2 0.6 0.2];...    % LUT7 
%                [0.2 0.6 0.2],[0.2 0.6 0.2],[0.2 0.6 0.2],[0.8 0.2 0.0],[0.2 0.6 0.2];...    % LUT8 
%                [0.2 0.6 0.2],[0.2 0.6 0.2],[0.2 0.6 0.2],[0.8 0.2 0.0],[0.2 0.6 0.2];...    % LUT9 
%                [0.2 0.6 0.2],[0.2 0.6 0.2],[0.2 0.6 0.2],[0.8 0.2 0.0],[0.2 0.6 0.2];...    % LUT10
%                [0.2 0.6 0.2],[0.2 0.6 0.2],[0.2 0.6 0.2],[0.8 0.2 0.0],[0.2 0.6 0.2];...    % LUT11
%                [0.2 0.6 0.2],[0.2 0.6 0.2],[0.2 0.6 0.2],[0.8 0.2 0.0],[0.2 0.6 0.2]};      % LUT12

dist_table7pri  = readmatrix(dt_file,'Sheet','Distributions_T7');
dist_table7pri(all(isnan(dist_table7pri),2),:) = []; % remove rows that are all NaN
dist_table7pri(:, all(isnan(dist_table7pri),1)) = []; % remove cols that are all NaN

dist_table7pri1 = dist_table7pri(:,1:3);
dist_table7pri1 = dist_table7pri1.';
dist_table71 = cell(size(dist_table7pri1,2), 1);
for ii = 1:size(dist_table71,1)
    dist_table71{ii,1} = dist_table7pri1(:, ii).';
end

dist_table7pri2 = dist_table7pri(:,4:6);
dist_table7pri2 = dist_table7pri2.';
dist_table72 = cell(size(dist_table7pri2,2), 1);
for ii = 1:size(dist_table72,1)
    dist_table72{ii,1} = dist_table7pri2(:, ii).';
end

dist_table7pri3 = dist_table7pri(:,7:9);
dist_table7pri3 = dist_table7pri3.';
dist_table73 = cell(size(dist_table7pri3,2), 1);
for ii = 1:size(dist_table73,1)
    dist_table73{ii,1} = dist_table7pri3(:, ii).';
end

dist_table7pri4 = dist_table7pri(:,10:12);
dist_table7pri4 = dist_table7pri4.';
dist_table74 = cell(size(dist_table7pri4,2), 1);
for ii = 1:size(dist_table74,1)
    dist_table74{ii,1} = dist_table7pri4(:, ii).';
end

dist_table7pri5 = dist_table7pri(:,13:15);
dist_table7pri5 = dist_table7pri5.';
dist_table75 = cell(size(dist_table7pri5,2), 1);
for ii = 1:size(dist_table75,1)
    dist_table75{ii,1} = dist_table7pri5(:, ii).';
end

dist_table7pri6 = dist_table7pri(:,16:18);
dist_table7pri6 = dist_table7pri6.';
dist_table76 = cell(size(dist_table7pri6,2), 1);
for ii = 1:size(dist_table76,1)
    dist_table76{ii,1} = dist_table7pri6(:, ii).';
end

dist_table7pri7 = dist_table7pri(:,19:21);
dist_table7pri7 = dist_table7pri7.';
dist_table77 = cell(size(dist_table7pri7,2), 1);
for ii = 1:size(dist_table77,1)
    dist_table77{ii,1} = dist_table7pri7(:, ii).';
end

dist_table7pri8 = dist_table7pri(:,22:24);
dist_table7pri8 = dist_table7pri8.';
dist_table78 = cell(size(dist_table7pri8,2), 1);
for ii = 1:size(dist_table78,1)
    dist_table78{ii,1} = dist_table7pri8(:, ii).';
end

dist_table7pri9 = dist_table7pri(:,25:27);
dist_table7pri9 = dist_table7pri9.';
dist_table79 = cell(size(dist_table7pri9,2), 1);
for ii = 1:size(dist_table79,1)
    dist_table79{ii,1} = dist_table7pri9(:, ii).';
end

dist_table7pri10 = dist_table7pri(:,28:30);
dist_table7pri10 = dist_table7pri10.';
dist_table710 = cell(size(dist_table7pri10,2), 1);
for ii = 1:size(dist_table710,1)
    dist_table710{ii,1} = dist_table7pri10(:, ii).';
end

dist_table7pri11 = dist_table7pri(:,31:33);
dist_table7pri11 = dist_table7pri11.';
dist_table711 = cell(size(dist_table7pri11,2), 1);
for ii = 1:size(dist_table711,1)
    dist_table711{ii,1} = dist_table7pri11(:, ii).';
end

dist_table7pri12 = dist_table7pri(:,34:36);
dist_table7pri12 = dist_table7pri12.';
dist_table712 = cell(size(dist_table7pri12,2), 1);
for ii = 1:size(dist_table712,1)
    dist_table712{ii,1} = dist_table7pri12(:, ii).';
end

dist_table7pri13 = dist_table7pri(:,37:39);
dist_table7pri13 = dist_table7pri13.';
dist_table713 = cell(size(dist_table7pri13,2), 1);
for ii = 1:size(dist_table713,1)
    dist_table713{ii,1} = dist_table7pri13(:, ii).';
end

dist_table7pri14 = dist_table7pri(:,40:42);
dist_table7pri14 = dist_table7pri14.';
dist_table714 = cell(size(dist_table7pri14,2), 1);
for ii = 1:size(dist_table714,1)
    dist_table714{ii,1} = dist_table7pri14(:, ii).';
end

dist_table7pri15 = dist_table7pri(:,43:45);
dist_table7pri15 = dist_table7pri15.';
dist_table715 = cell(size(dist_table7pri15,2), 1);
for ii = 1:size(dist_table715,1)
    dist_table715{ii,1} = dist_table7pri15(:, ii).';
end

dist_table7 = [dist_table71 dist_table72 dist_table73 dist_table74 dist_table75...
    dist_table76 dist_table77 dist_table78 dist_table79 dist_table710...
    dist_table711 dist_table712 dist_table713 dist_table714 dist_table715];

%              |LRS1|LRS2|LRS3|LRS4|LRS5|
% dist_table8 = {[0.15 0.25 0.25 0.15 0.20];...   % LUT1
%                [0.15 0.25 0.25 0.15 0.20];...   % LUT2
%                [0.15 0.25 0.25 0.15 0.20];...   % LUT3
%                [0.15 0.25 0.25 0.15 0.20];...   % LUT4
%                [0.15 0.25 0.25 0.15 0.20];...   % LUT5
%                [0.15 0.25 0.25 0.15 0.20];...   % LUT6
%                [0.15 0.25 0.25 0.15 0.20];...   % LUT7
%                [0.15 0.25 0.25 0.15 0.20];...   % LUT8
%                [0.15 0.25 0.25 0.15 0.20];...   % LUT9
%                [0.15 0.25 0.25 0.15 0.20];...   % LUT10
%                [0.15 0.25 0.25 0.15 0.20];...   % LUT11
%                [0.15 0.25 0.25 0.15 0.20]};     % LUT12

dist_table8pri = readmatrix(dt_file,'Sheet','Distributions_T8');
dist_table8pri(all(isnan(dist_table8pri),2),:) = []; % remove rows that are all NaN
dist_table8pri(:, all(isnan(dist_table8pri),1)) = []; % remove cols that are all NaN
dist_table8pri = dist_table8pri(:, 1:end-1); % remove sum column
dist_table8pri = dist_table8pri.';
dist_table8 = cell(size(dist_table8pri,2), 1);
for ii = 1:size(dist_table8,1)
    dist_table8{ii,1} = dist_table8pri(:, ii).';
end

TV0_data_household(1).bldID = []; % Initialize    
TV0_data_building = struct('zoneID',[],'bldID',[],'nHouse',[],'residents',[],...
    'specialFac',[],'expStr', [],'fptarea',[],'nstoreys',[],'lrstype',[],'assigned',[],'lut_number',[]);
bld_numb = 0;

tv0dhzoneID = [TV0_data_household(:).zoneID].';
tv0dhhhID = [TV0_data_household(:).hhID].';

for zone_idx = 1: size(TV0_data_landuse,1)
    if TV0_data_landuse.densityCap(zone_idx) ~= 0
        zoneid = TV0_data_landuse.zoneID(zone_idx);
        lut = TV0_data_landuse.LuF(zone_idx);
        avg_income = TV0_data_landuse.avgIncome(zone_idx);
        lut_number = zone_idx; %find(strcmp(land_use_types,lut));
        income_number = find(strcmp(avg_income_types,avg_income));
        if totalbldarea_res(zone_idx)==0 % if there are no residential buildings skip it.
            continue
        end    
        total_generated_bld_area = 0;
        flag = true;    
        while flag
            % find out a building
            try
                building = generate_new_building(lut_number, dist_table8, dist_table7, fpt_area{income_number}, storey_info);
            catch
                warndlg('Please check your Distribution Table 7 and/or 8!','!!!ERROR!!!')
                delete(wb)
                %clearvars
                return
            end

            if building(2)*building(3) < min(Average_dwelling_area)   
                continue;
            end
            total_generated_bld_area = total_generated_bld_area + building(2)*building(3);
            bld_numb = bld_numb+1;
            TV0_data_building(bld_numb,1).zoneID = zoneid;
            TV0_data_building(bld_numb,1).bldID = bld_numb;
            TV0_data_building(bld_numb,1).fptarea = building(3);
            TV0_data_building(bld_numb,1).nstoreys = building(2);
            TV0_data_building(bld_numb,1).lrstype = building(1);
            TV0_data_building(bld_numb,1).assigned = 0;
            TV0_data_building(bld_numb,1).lut_number = lut_number; % Passive
            if total_generated_bld_area>totalbldarea_res(zone_idx)
                % Assign households randomly 
                temp_households_indx = tv0dhzoneID == zoneid;
                temp_household_data_wrt_zone = TV0_data_household(temp_households_indx);
                empty_bldid_households_idx = cellfun(@isempty, {temp_household_data_wrt_zone(:).bldID}.'); % Find out households with empty bldID
    
                if sum(empty_bldid_households_idx)==0
                    flag=false;
                    TV0_data_building(bld_numb) = [];
                    bld_numb = bld_numb -1 ; 
                else
                    households_tobe_assigned=temp_household_data_wrt_zone(empty_bldid_households_idx); % Get households info that will be assigned
                    temp_buildings_indx = [TV0_data_building(:).zoneID].' ==zoneid;
                    temp_building_data_wrt_zone = TV0_data_building(temp_buildings_indx);
                    buildings_tobe_assigned = temp_building_data_wrt_zone([temp_building_data_wrt_zone(:).assigned].'==0);   % Get buildings without any assignment           
                    for bld_id = 1:size(buildings_tobe_assigned,1) % For all buildings, assign households.
                        bld_total_area = buildings_tobe_assigned(bld_id).nstoreys * buildings_tobe_assigned(bld_id).fptarea ;
                        tot_households = size(households_tobe_assigned,1);
                        households_indx_tobe_assigned = randperm(tot_households,tot_households);
                        for j = 1:length(households_indx_tobe_assigned) 
                            indx = households_indx_tobe_assigned(j);
                            erased_area = Average_dwelling_area(households_tobe_assigned(indx).income_numb);
                            residual = bld_total_area - erased_area; 
                            if residual>0
                                bld_total_area = bld_total_area - erased_area;
                                TV0_data_household(tv0dhhhID == households_tobe_assigned(indx).hhID).bldID = buildings_tobe_assigned(bld_id).bldID;
                                TV0_data_building([TV0_data_building(:).bldID].' == buildings_tobe_assigned(bld_id).bldID).assigned =1;  % Do not assign anymore                                                      
                            end
                            if bld_total_area<min(Average_dwelling_area)
                                break;
                            end
                        end
                        temp_households_indx = tv0dhzoneID == zoneid;
                        temp_household_data_wrt_zone = TV0_data_household(temp_households_indx);
                        empty_bldid_households_idx = cellfun(@isempty, {temp_household_data_wrt_zone(:).bldID}.'); % Find out households with empty bldID
                        households_tobe_assigned = temp_household_data_wrt_zone(empty_bldid_households_idx);
                    end
                end
            end
        end
    else
        % do not generate building
    end  
end

% Clear out the buildings without any households
bld_numb_indx = [TV0_data_building(:).assigned].' == 0;
TV0_data_building(bld_numb_indx) = [];

% -------------------------------------------------------------------------
% STEP13 Identify and assign occupation attribute and SpecialFac status for residential buildings
% -------------------------------------------------------------------------

waitbar(13/26, wb, 'Processing - Step 13');

TV0_data_building(1).OccBld = [];
% Sum up household and building layer data, findout nHouse and residents
for i = 1: size(TV0_data_building,1)    
    TV0_data_building(i).specialFac = 0;
    TV0_data_building(i).OccBld = 'Res';
end

% -------------------------------------------------------------------------
% STEP14 Identify and assign code level for residential buildings
% -------------------------------------------------------------------------

waitbar(14/26, wb, 'Processing - Step 14');

% Code Level Types
% 1 - LC
% 2 - MC
% 3 - HC
% code_level_types = {'LC', 'MC', 'HC'};

code_level_types = readcell(dt_file,'Sheet','Distributions_T11','Range','B9:B11').';

%              |   LRS1    |    LRS2     |    LRS3     |    LRS4     |    LRS5     |
%              |LC |MC |HC |  LC |MC |HC |  LC |MC |HC |  LC |MC |HC |  LC |MC |HC |
% dist_table11 ={[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1];...    % LUT1 
%                [0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1];...    % LUT2 
%                [0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1];...    % LUT3 
%                [0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1];...    % LUT4 
%                [0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1];...    % LUT5 
%                [0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1];...    % LUT6 
%                [0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1];...    % LUT7 
%                [0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1];...    % LUT8 
%                [0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1];...    % LUT9 
%                [0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1];...    % LUT10
%                [0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1];...    % LUT11
%                [0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1]};      % LUT12

dist_table11pri = readmatrix(dt_file,'Sheet','Distributions_T11');
dist_table11pri(all(isnan(dist_table11pri),2),:) = []; % remove rows that are all NaN
dist_table11pri(:, all(isnan(dist_table11pri),1)) = []; % remove cols that are all NaN

dist_table11pri1 = dist_table11pri(:,1:3);
dist_table11pri1 = dist_table11pri1.';
dist_table111 = cell(size(dist_table11pri1,2), 1);
for ii = 1:size(dist_table111,1)
    dist_table111{ii,1} = dist_table11pri1(:, ii).';
end

dist_table11pri2 = dist_table11pri(:,4:6);
dist_table11pri2 = dist_table11pri2.';
dist_table112 = cell(size(dist_table11pri2,2), 1);
for ii = 1:size(dist_table112,1)
    dist_table112{ii,1} = dist_table11pri2(:, ii).';
end

dist_table11pri3 = dist_table11pri(:,7:9);
dist_table11pri3 = dist_table11pri3.';
dist_table113 = cell(size(dist_table11pri3,2), 1);
for ii = 1:size(dist_table113,1)
    dist_table113{ii,1} = dist_table11pri3(:, ii).';
end

dist_table11pri4 = dist_table11pri(:,10:12);
dist_table11pri4 = dist_table11pri4.';
dist_table114 = cell(size(dist_table11pri4,2), 1);
for ii = 1:size(dist_table114,1)
    dist_table114{ii,1} = dist_table11pri4(:, ii).';
end

dist_table11pri5 = dist_table11pri(:,13:15);
dist_table11pri5 = dist_table11pri5.';
dist_table115 = cell(size(dist_table11pri5,2), 1);
for ii = 1:size(dist_table115,1)
    dist_table115{ii,1} = dist_table11pri5(:, ii).';
end

dist_table11pri6 = dist_table11pri(:,16:18);
dist_table11pri6 = dist_table11pri6.';
dist_table116 = cell(size(dist_table11pri6,2), 1);
for ii = 1:size(dist_table116,1)
    dist_table116{ii,1} = dist_table11pri6(:, ii).';
end

dist_table11pri7 = dist_table11pri(:,19:21);
dist_table11pri7 = dist_table11pri7.';
dist_table117 = cell(size(dist_table11pri7,2), 1);
for ii = 1:size(dist_table117,1)
    dist_table117{ii,1} = dist_table11pri7(:, ii).';
end

dist_table11pri8 = dist_table11pri(:,22:24);
dist_table11pri8 = dist_table11pri8.';
dist_table118 = cell(size(dist_table11pri8,2), 1);
for ii = 1:size(dist_table118,1)
    dist_table118{ii,1} = dist_table11pri8(:, ii).';
end

dist_table11pri9 = dist_table11pri(:,25:27);
dist_table11pri9 = dist_table11pri9.';
dist_table119 = cell(size(dist_table11pri9,2), 1);
for ii = 1:size(dist_table119,1)
    dist_table119{ii,1} = dist_table11pri9(:, ii).';
end

dist_table11pri10 = dist_table11pri(:,28:30);
dist_table11pri10 = dist_table11pri10.';
dist_table1110 = cell(size(dist_table11pri10,2), 1);
for ii = 1:size(dist_table1110,1)
    dist_table1110{ii,1} = dist_table11pri10(:, ii).';
end

dist_table11pri11 = dist_table11pri(:,31:33);
dist_table11pri11 = dist_table11pri11.';
dist_table1111 = cell(size(dist_table11pri11,2), 1);
for ii = 1:size(dist_table1111,1)
    dist_table1111{ii,1} = dist_table11pri11(:, ii).';
end

dist_table11pri12 = dist_table11pri(:,34:36);
dist_table11pri12 = dist_table11pri12.';
dist_table1112 = cell(size(dist_table11pri12,2), 1);
for ii = 1:size(dist_table1112,1)
    dist_table1112{ii,1} = dist_table11pri12(:, ii).';
end

dist_table11pri13 = dist_table11pri(:,37:39);
dist_table11pri13 = dist_table11pri13.';
dist_table1113 = cell(size(dist_table11pri13,2), 1);
for ii = 1:size(dist_table1113,1)
    dist_table1113{ii,1} = dist_table11pri13(:, ii).';
end

dist_table11pri14 = dist_table11pri(:,40:42);
dist_table11pri14 = dist_table11pri14.';
dist_table1114 = cell(size(dist_table11pri14,2), 1);
for ii = 1:size(dist_table1114,1)
    dist_table1114{ii,1} = dist_table11pri14(:, ii).';
end

dist_table11pri15 = dist_table11pri(:,43:45);
dist_table11pri15 = dist_table11pri15.';
dist_table1115 = cell(size(dist_table11pri15,2), 1);
for ii = 1:size(dist_table1115,1)
    dist_table1115{ii,1} = dist_table11pri15(:, ii).';
end

dist_table11 = [dist_table111 dist_table112 dist_table113 dist_table114 dist_table115...
    dist_table116 dist_table117 dist_table118 dist_table119 dist_table1110...
    dist_table1111 dist_table1112 dist_table1113 dist_table1114 dist_table1115];

tv0dblrstype = [TV0_data_building(:).lrstype].';
tv0dblutnumber = [TV0_data_building(:).lut_number].';
TV0_data_building(1).CodeLevel = []; % Initialize
for lrs_indx = 1:length(lrs_types)
    for lut_indx = 1:length(land_use_types)
        code_level_prob = dist_table11{lut_indx,lrs_indx};
        temp_building_indx = and(tv0dblrstype == lrs_indx , tv0dblutnumber == lut_indx );
        % Find Total number of buildings for different lrs types and lut
        % numbers
        codelevel_of_buildings = dist_table11{lut_indx,lrs_indx}*sum(temp_building_indx);
        % Find the cumulative sum  
        cumsum_cl_num = round(cumsum(codelevel_of_buildings));
        % Make it a column vector
        column_vector = cumsum2vector(cumsum_cl_num);
        % Randomly permute the education attainment status
        sample_idx = randperm(length(column_vector));
        % Assign randomly permuted education attainment status into individuals
        temp_numb = num2cell(column_vector(sample_idx));   
        [TV0_data_building(temp_building_indx).CodeLevel] = deal(temp_numb{:});
    end
end

% -------------------------------------------------------------------------
% STEP15 Assign exposure string for each residential building
% -------------------------------------------------------------------------

waitbar(15/26, wb, 'Processing - Step 15');

% expStr= LRSBld+CLBld+nStoreyBld+OccBld

for bld_id = 1: size(TV0_data_building,1)
    temp_lrs = TV0_data_building(bld_id).lrstype; % Find out lrs number
    lrs_str = lrs_types{temp_lrs} ; % LRS string
    temp_codelevel = TV0_data_building(bld_id).CodeLevel; % find out code level numb
    cl_str = code_level_types{temp_codelevel}; % Code Level String
    temp_nstoreys = TV0_data_building(bld_id).nstoreys; % Find out Nstoreys numb
    nstoreys_str = [num2str(temp_nstoreys) 's'] ; % Number of storeys string
    occ_bld_str = TV0_data_building(bld_id).OccBld ;
    TV0_data_building(bld_id).expStr =  [lrs_str,'+',cl_str,'+',nstoreys_str,'+',occ_bld_str];
end

% -------------------------------------------------------------------------
% STEP16 Identify and assign number of households and residents for each residential building
% -------------------------------------------------------------------------

waitbar(16/26, wb, 'Processing - Step 16');

% Sum up household and building layer data, findout nHouse and residents
tv0dhbldID = [TV0_data_household(:).bldID].';
for i = 1: size(TV0_data_building,1)
    temp_indx = tv0dhbldID == TV0_data_building(i).bldID ;
    temp_nHouse = sum(temp_indx); 
    temp_residents = sum([TV0_data_household(temp_indx).nInd].');
    TV0_data_building(i).nHouse = temp_nHouse;
    TV0_data_building(i).residents = temp_residents;
end

% -------------------------------------------------------------------------
% STEP17 Identify and generate commercial and industrial buildings
% -------------------------------------------------------------------------

waitbar(17/26, wb, 'Processing - Step 17');

% Assumption : 
% Nr of commercial buildings per 1000 individuals
% Nr of industrial buildings per 1000 individuals

numb_com = readmatrix(dt_file,'Sheet','Assumptions','Range','C42:C42');
numb_ind = readmatrix(dt_file,'Sheet','Assumptions','Range','C46:C46');

total_individuals = sum([TV0_data_building(:).residents].');

%                Res Com Ind ResCom
% dist_table9 = {[1.0 0.0 0.0 0.0];... % LUT1 'AGRICULTURE'
%                [0.0 0.0 1.0 0.0];... % LUT2 'CITY CENTER' 
%                [0.0 0.0 1.0 0.0];... % LUT3 'COMMERCIAL AND RESIDENTIAL'
%                [0.6 0.0 0.3 0.1];... % LUT4 'HISTORICAL PRESERVATION AREA'
%                [0.0 1.0 0.0 0.0];... % LUT5 'INDUSTRY'
%                [0.0 1.0 0.0 0.0];... % LUT6 'NEW DEVELOPMENT'
%                [0.7 0.0 0.1 0.2];... % LUT7 'NEW PLANNING' 
%                [0.6 0.0 0.1 0.3];... % LUT8 'RECREATION AREA'
%                [0.5 0.0 0.4 0.1];... % LUT9 'RESIDENTIAL (GATED NEIGHBORHOOD)'
%                [0.7 0.0 0.1 0.2];... % LUT10 'RESIDENTIAL (HIGH DENSITY)'
%                [0.6 0.0 0.1 0.3];... % LUT11 'RESIDENTIAL (LOW DENSITY)' 
%                [0.5 0.0 0.4 0.1]};   % LUT12 'RESIDENTIAL (MODERATE DENSITY)'

dist_table9pri0 = readmatrix(dt_file,'Sheet','Distributions_T9');
dist_table9pri0(all(isnan(dist_table9pri0),2),:) = []; % remove rows that are all NaN
dist_table9pri0(:, all(isnan(dist_table9pri0),1)) = []; % remove cols that are all NaN

dist_table9pri1 = dist_table9pri0(:,1); % Res
dist_table9pri4 = dist_table9pri0(:,2); % ResCom
dist_table9pri2 = dist_table9pri0(:,4); % Com
dist_table9pri3 = dist_table9pri0(:,6); % Ind

dist_table9pri = [dist_table9pri1 dist_table9pri2 dist_table9pri3 dist_table9pri4];
dist_table9pri = dist_table9pri.';
dist_table9 = cell(size(dist_table9pri,2), 1);
for ii = 1:size(dist_table9,1)
    dist_table9{ii,1} = dist_table9pri(:, ii).';
end

% Initialise
total_ind_prob = 0;
total_com_prob = 0;
numb_res = zeros(length(land_use_types),1);
temp_numb_ind = zeros(length(land_use_types),1);
temp_numb_com = zeros(length(land_use_types),1);
temp_numb_rescom = zeros(length(land_use_types),1);

tv0dblutnumber = [TV0_data_building(:).lut_number].';

for lut_indx = 1:length(land_use_types)
    building_occ_prob = dist_table9{lut_indx};    
    if building_occ_prob(1)>0 % If there are residential buildings
        temp_building_indx = tv0dblutnumber == lut_indx;
        numb_res(lut_indx) = sum(temp_building_indx); % Find Total number of buildings (Residential) for different lut numbers        
        temp_numb_com(lut_indx) = round((numb_res(lut_indx)*building_occ_prob(2))/(building_occ_prob(1)+building_occ_prob(4)));
        temp_numb_ind(lut_indx) = round((numb_res(lut_indx)*building_occ_prob(3))/(building_occ_prob(1)+building_occ_prob(4)));       
        temp_numb_rescom(lut_indx) = round((numb_res(lut_indx)*building_occ_prob(4))/(building_occ_prob(1)+building_occ_prob(4))); % Total number of rescom buildings
    else
        total_com_prob = total_com_prob + building_occ_prob(2); 
        total_ind_prob = total_ind_prob + building_occ_prob(3);     
    end
end

% max_com_buildings = round((total_individuals*numb_com )/1000); % Find out max commercial buildings
% max_ind_buildings = round((total_individuals*numb_ind )/1000); % Find out max industrial buildings

max_com_buildings = numb_com; % Find out max commercial buildings
max_ind_buildings = numb_ind; % Find out max industrial buildings

% If there are problems warn the user
%if sum(temp_numb_com) > max_com_buildings
    %warndlg('Please revise the number of "com/ind" buildings in Assumption 10 and/or probabilities in Table 9!','!!!ERROR!!!')
    %delete(wb)
    %clearvars
    %return
%end
%if sum(temp_numb_ind) > max_ind_buildings 
    %warndlg('Please revise the number of "com/ind" buildings in Assumption 11 and/or probabilities in Table 9','!!!ERROR!!!')
    %delete(wb)
    %clearvars
    %return
%end

try 
    % Calculate generated commercial and industrial buildings
    generated_buildings_com = max_com_buildings - sum(temp_numb_com); % this difference will be generated in other LUTs wrt dist_table9
    generated_buildings_ind = max_ind_buildings - sum(temp_numb_ind);
    
    % Lut number of Com buildings 
    table9 = cell2mat(dist_table9);
    Com_Table = table9(1:height(land_use_types),2) .* double(table9(1:height(land_use_types),1)==0);
    if sum(Com_Table) ~= 0
        Com_prob = Com_Table/sum(Com_Table);
    else
        Com_prob = 0;
    end
    com_buildings_new= Com_prob*generated_buildings_com;
    com_buildings_total = com_buildings_new + temp_numb_com;
    % Find the cumulative sum  
    cumsum_combuildings_num = round(cumsum(com_buildings_total));
    % Make it a column vector
    cumsum_combuildings_num(isnan(cumsum_combuildings_num))=0;
    column_vector = cumsum2vector(cumsum_combuildings_num);
    % Randomly permute the code level status
    sample_idx = randperm(length(column_vector));
    % Assign randomly permuted code level into buildings
    com_buildings_lut_numb = column_vector(sample_idx);
    
    % Lut number of Ind Buildings
    table9 = cell2mat(dist_table9);
    Ind_Table = table9(1:height(land_use_types),3) .* double(table9(1:height(land_use_types),1)==0);
    if sum(Ind_Table) ~= 0
        Ind_prob = Ind_Table/sum(Ind_Table);
    else
        Ind_prob = 0;
    end
    ind_buildings_new = Ind_prob*generated_buildings_ind;
    ind_buildings_total = ind_buildings_new + temp_numb_ind;
    % Find the cumulative sum  
    cumsum_indbuildings_num = round(cumsum(ind_buildings_total));
    % Make it a column vector
    cumsum_indbuildings_num(isnan(cumsum_indbuildings_num))=0;
    column_vector=cumsum2vector(cumsum_indbuildings_num);
    % Randomly permute the code level status
    sample_idx = randperm(length(column_vector));
    % Assign randomly permuted code level into buildings
    ind_buildings_lut_numb = column_vector(sample_idx);
catch
    warndlg('Please check your Distribution Table 9!','!!!ERROR!!!')
    delete(wb)
    clearvars
    return
end

tv0dblutnumber = [TV0_data_building(:).lut_number].';

% Some of the Res buildings have changed with Res+Com
% The numbers of the changes are kept in temp_numb_rescom
% Res+Com will be assigned randomly

for lut_indx = 1:length(land_use_types)
    if temp_numb_rescom(lut_indx)~=0
        temp_building_indx = tv0dblutnumber == lut_indx;
        buildings_indicator = find(temp_building_indx);
        rescom_ids=randperm(length(buildings_indicator),temp_numb_rescom(lut_indx));
        [TV0_data_building(rescom_ids).OccBld] = deal('ResCom') ;
    end
end

% Generate expStr again
% expStr= LRSBld+CLBld+nStoreyBld+OccBld

for bld_id = 1: size(TV0_data_building,1)
    temp_lrs = TV0_data_building(bld_id).lrstype; % Find out lrs number
    lrs_str = lrs_types{temp_lrs} ; % LRS string
    temp_codelevel = TV0_data_building(bld_id).CodeLevel; % find out code level numb
    cl_str = code_level_types{temp_codelevel}; % Code Level String
    temp_nstoreys = TV0_data_building(bld_id).nstoreys; % Find out Nstoreys numb
    nstoreys_str = [num2str(temp_nstoreys) 's'] ; % Number of storeys string
    occ_bld_str = TV0_data_building(bld_id).OccBld ;
    TV0_data_building(bld_id).expStr =  [lrs_str,'+',cl_str,'+',nstoreys_str,'+',occ_bld_str];
end

% -------------------------------------------------------------------------
% STEP18 Identify and assign the attributes for commercial and industrial buildings
% -------------------------------------------------------------------------

waitbar(18/26, wb, 'Processing - Step 18');

%               FPT-Range Ns     Code Level    LRS Type
% dist_table10 = {[95 150]  [5 10] [0.2 0.5 0.3] [0.1 0.3 0.2 0.3 0.1];... % Com
%                 [85 105]  [5 10] [0.2 0.4 0.4] [0.1 0.3 0.2 0.3 0.1]};   % Ind

dist_table10pri1 = readmatrix(dt_file,'Sheet','Distributions','Range','B75:C76');
dist_table10pri1 = dist_table10pri1.';
dist_table101 = cell(size(dist_table10pri1,2), 1);
for ii = 1:size(dist_table101,1)
    dist_table101{ii,1} = dist_table10pri1(:, ii).';
end

dist_table10pri2 = readmatrix(dt_file,'Sheet','Distributions','Range','D75:E76');
dist_table10pri2 = dist_table10pri2.';
dist_table102 = cell(size(dist_table10pri2,2), 1);
for ii = 1:size(dist_table102,1)
    dist_table102{ii,1} = dist_table10pri2(:, ii).';
end

dist_table10pri3 = readmatrix(dt_file,'Sheet','Distributions','Range','F75:H76');
dist_table10pri3 = dist_table10pri3.';
dist_table103 = cell(size(dist_table10pri3,2), 1);
for ii = 1:size(dist_table103,1)
    dist_table103{ii,1} = dist_table10pri3(:, ii).';
end

dist_table10pri4 = readmatrix(dt_file,'Sheet','Distributions','Range','I75:W76');
dist_table10pri4 = dist_table10pri4.';
dist_table104 = cell(size(dist_table10pri4,2), 1);
for ii = 1:size(dist_table104,1)
    dist_table104{ii,1} = dist_table10pri4(:, ii).';
end

dist_table10 = [dist_table101 dist_table102 dist_table103 dist_table104];

total_com_ind_buildings = cell(2,1);
for i =1:2 % For Com and Ind buildings
    % For fpt,NStoreys, Code LEvel, LRS Type
    temp_info_fpt = dist_table10{i,1};
    temp_n_storeys = dist_table10{i,2};
    temp_code_level = dist_table10{i,3};
    temp_lrs_type = dist_table10{i,4};
    
    if i==1
        total_bld_numb = max_com_buildings;
    elseif i==2
        total_bld_numb = max_ind_buildings;
    end
    fpt_numb = round(temp_info_fpt(1)+ (temp_info_fpt(2)-temp_info_fpt(1))*rand(total_bld_numb,1));
    n_storeys_numb = round(temp_n_storeys(1)+ (temp_n_storeys(2)-temp_n_storeys(1))*rand(total_bld_numb,1));
    % Find Total number of buildings for different code level
    codellevel_of_buildings = temp_code_level*total_bld_numb;
    % Find the cumulative sum  
    cumsum_codelevel_num = round(cumsum(codellevel_of_buildings));
    % Make it a column vector
    column_vector = cumsum2vector(cumsum_codelevel_num);
    % Randomly permute the code level status
    sample_idx = randperm(length(column_vector));
    % Assign randomly permuted code level into buildings
    code_level_numb = column_vector(sample_idx);

    % Find Total number of buildings for different lrs
    lrs_of_buildings = temp_lrs_type*total_bld_numb;
    % Find the cumulative sum  
    cumsum_lrs_num = round(cumsum(lrs_of_buildings));
    % Make it a column vector
    column_vector = cumsum2vector(cumsum_lrs_num);
    % Randomly permute the code level status
    sample_idx = randperm(length(column_vector));
    % Assign randomly permuted code level into buildings
    lrs_numb = column_vector(sample_idx);
    
    total_com_ind_buildings(i) = {[fpt_numb, n_storeys_numb, code_level_numb, lrs_numb]};
end

% Sum up all buildings files together
Com_buildings_numb = size(total_com_ind_buildings{1},1);
bld_id = size(TV0_data_building,1);
bld_id2 = max([TV0_data_building(:).bldID]); 
Commercial_buildings_info = total_com_ind_buildings{1};
for i = 1 : generated_buildings_com
    TV0_data_building(bld_id+i).bldID = bld_id2+i; % Building Id
    TV0_data_building(bld_id+i).nHouse = 0;
    TV0_data_building(bld_id+i).residents = 0;
    TV0_data_building(bld_id+i).specialFac = 0;
    TV0_data_building(bld_id+i).fptarea = Commercial_buildings_info(i,1);
    TV0_data_building(bld_id+i).nstoreys= Commercial_buildings_info(i,2);
    TV0_data_building(bld_id+i).lrstype = Commercial_buildings_info(i,4);
    TV0_data_building(bld_id+i).CodeLevel = Commercial_buildings_info(i,3);
    TV0_data_building(bld_id+i).OccBld = 'Com';
    TV0_data_building(bld_id+i).lut_number = com_buildings_lut_numb(i);
    TV0_data_building(bld_id+i).expStr = [lrs_types{TV0_data_building(bld_id+i).lrstype}, '+',...
                                          code_level_types{TV0_data_building(bld_id+i).CodeLevel},'+'...
                                          [num2str(TV0_data_building(bld_id+i).nstoreys) 's'],'+',...
                                          TV0_data_building(bld_id+i).OccBld];
end

Ind_buildings_numb = size(total_com_ind_buildings{2},1);
Industrial_buildings_info = total_com_ind_buildings{2};
bld_id = size(TV0_data_building,1);
bld_id2 = max([TV0_data_building(:).bldID]);
for i = 1 : Ind_buildings_numb
    TV0_data_building(bld_id+i).bldID = bld_id2+i; % Building Id
    TV0_data_building(bld_id+i).nHouse = 0;
    TV0_data_building(bld_id+i).residents = 0;
    TV0_data_building(bld_id+i).specialFac = 0;
    TV0_data_building(bld_id+i).fptarea = Industrial_buildings_info(i,1);
    TV0_data_building(bld_id+i).nstoreys= Industrial_buildings_info(i,2);
    TV0_data_building(bld_id+i).lrstype = Industrial_buildings_info(i,4);
    TV0_data_building(bld_id+i).CodeLevel = Industrial_buildings_info(i,3);
    TV0_data_building(bld_id+i).OccBld = 'Ind';
    TV0_data_building(bld_id+i).lut_number = ind_buildings_lut_numb(i);
    TV0_data_building(bld_id+i).expStr = [lrs_types{TV0_data_building(bld_id+i).lrstype}, '+',...
                                          code_level_types{TV0_data_building(bld_id+i).CodeLevel},'+'...
                                          [num2str(TV0_data_building(bld_id+i).nstoreys) 's'],'+',...
                                          TV0_data_building(bld_id+i).OccBld];
end

% Find out LUT number of every zone, and their zone id
zoneid = zeros(size(TV0_data_landuse,1),1);
lut_number = zeros(size(TV0_data_landuse,1),1);
for zone_idx = 1: size(TV0_data_landuse,1) 
    zoneid(zone_idx) = TV0_data_landuse.zoneID(zone_idx);
    lut = TV0_data_landuse.LuF(zone_idx);
    if any(strcmp(land_use_types,lut))
        lut_number(zone_idx) = zone_idx; %find(strcmp(land_use_types,lut));
    else
        lut_number(zone_idx) = 0;
    end
end

% Assing zone id randomly, by controlling their Lut number
empty_zoneid_buildings_idx = cellfun(@isempty, {TV0_data_building(:).zoneID}.');
all_buildings_without_zoneid = TV0_data_building(empty_zoneid_buildings_idx);

tv0dbbldID = [TV0_data_building(:).bldID].';

for i = 1: length(land_use_types)
    indx_buildings = [all_buildings_without_zoneid(:).lut_number].' == i ;
    if sum(indx_buildings)==0 % If there are no buildings in the given lut type, continue
        continue;
    end
    building_ids = [all_buildings_without_zoneid(indx_buildings).bldID].';
    % Find different zone ids with lut number i
    possible_zones = zoneid(lut_number(:)==i);
    total_zone_number = length(possible_zones);
    random_zones = round(1+ (total_zone_number-1)*rand(sum(indx_buildings),1));    
    zone_ids = possible_zones(random_zones);
    % Assign Building Ids zone ids
    for k = 1 : length(building_ids)
        TV0_data_building(tv0dbbldID == building_ids(k)).zoneID = zone_ids(k);
    end
end

% -------------------------------------------------------------------------
% STEP19 Generate school and hospitals
% -------------------------------------------------------------------------

waitbar(19/26, wb, 'Processing - Step 19');

% Assumption : 
% 1 school per x individuals
% 1 hospital per y individuals

total_individuals = sum([TV0_data_building(:).residents].');
numb_school =  round(total_individuals/readmatrix(dt_file,'Sheet','Assumptions','Range','C57:C57')); % School specialFac=1
if numb_school == 0
    numb_school = 1;
end
numb_hospital = round(total_individuals/readmatrix(dt_file,'Sheet','Assumptions','Range','C61:C61')); % Hospital specialFac=2
if numb_hospital == 0
    numb_hospital = 1;
end

% -------------------------------------------------------------------------
% STEP20 Generate expStr for schools and hospitals
% -------------------------------------------------------------------------

waitbar(20/26, wb, 'Processing - Step 20');

%               FPT-Range Ns     Code Level    LRS Type
% dist_table14 = {[95 150]  [5 10] [0.2 0.5 0.3] [0.1 0.3 0.2 0.3 0.1];... % School
%                 [85 105]  [5 10] [0.2 0.4 0.4] [0.1 0.3 0.2 0.3 0.1]};   % Hospital

dist_table14pri1 = readmatrix(dt_file,'Sheet','Distributions','Range','B82:C83');
dist_table14pri1 = dist_table14pri1.';
dist_table141 = cell(size(dist_table14pri1,2), 1);
for ii = 1:size(dist_table141,1)
    dist_table141{ii,1} = dist_table14pri1(:, ii).';
end

dist_table14pri2 = readmatrix(dt_file,'Sheet','Distributions','Range','D82:E83');
dist_table14pri2 = dist_table14pri2.';
dist_table142 = cell(size(dist_table14pri2,2), 1);
for ii = 1:size(dist_table142,1)
    dist_table142{ii,1} = dist_table14pri2(:, ii).';
end

dist_table14pri3 = readmatrix(dt_file,'Sheet','Distributions','Range','F82:H83');
dist_table14pri3 = dist_table14pri3.';
dist_table143 = cell(size(dist_table14pri3,2), 1);
for ii = 1:size(dist_table143,1)
    dist_table143{ii,1} = dist_table14pri3(:, ii).';
end

dist_table14pri4 = readmatrix(dt_file,'Sheet','Distributions','Range','I82:W83');
dist_table14pri4 = dist_table14pri4.';
dist_table144 = cell(size(dist_table14pri4,2), 1);
for ii = 1:size(dist_table144,1)
    dist_table144{ii,1} = dist_table14pri4(:, ii).';
end

dist_table14 = [dist_table141 dist_table142 dist_table143 dist_table144];

total_specialfac_buildings = cell(2,1);
for i =1:2 % For Com and Ind buildings
    % For fpt,NStoreys, Code LEvel, LRS Type
    temp_info_fpt = dist_table14{i,1};
    temp_n_storeys = dist_table14{i,2};
    temp_code_level = dist_table14{i,3};
    temp_lrs_type = dist_table14{i,4};
    
    if i==1
        total_bld_numb = numb_school;
    elseif i==2
        total_bld_numb = numb_hospital;
    end
    fpt_numb = round(temp_info_fpt(1)+ (temp_info_fpt(2)-temp_info_fpt(1))*rand(total_bld_numb,1));
    n_storeys_numb = round(temp_n_storeys(1)+ (temp_n_storeys(2)-temp_n_storeys(1))*rand(total_bld_numb,1));
    % Find total number of buildings for different code level
    codellevel_of_buildings = temp_code_level*total_bld_numb;
    % Find the cumulative sum  
    cumsum_codelevel_num = round(cumsum(codellevel_of_buildings));
    % Make it a column vector
    column_vector = cumsum2vector(cumsum_codelevel_num);
    % Randomly permute the code level status
    sample_idx = randperm(length(column_vector));
    % Assign randomly permuted code level into buildings
    code_level_numb = column_vector(sample_idx);

    % Find total number of buildings for different lrs
    lrs_of_buildings = temp_lrs_type*total_bld_numb;
    % Find the cumulative sum  
    cumsum_lrs_num = round(cumsum(lrs_of_buildings));
    % Make it a column vector
    column_vector = cumsum2vector(cumsum_lrs_num);
    % Randomly permute the code level status
    sample_idx = randperm(length(column_vector));
    % Assign randomly permuted code level into buildings
    lrs_numb = column_vector(sample_idx);
    
    total_specialfac_buildings(i) = {[fpt_numb, n_storeys_numb,code_level_numb,lrs_numb]};
end

% Assign schools and hospitals to zones starting from the highest 
% population until the number of schools and hospitals are reached
unique_zone_list = unique([TV0_data_building(:).zoneID]);

% Find out population in every zone and sort with descending order
tv0dbzoneID = [TV0_data_building(:).zoneID].';
total_pop = zeros(length(unique_zone_list),1);
for i = 1:length(unique_zone_list)
    total_pop(i) = sum([TV0_data_building(tv0dbzoneID == unique_zone_list(i)).residents]);
end
[val,idx]= sort(total_pop,'descend'); % val represents the population number

rmv_zeros = find(val == 0); % find unresidential zoneIDs
idx(rmv_zeros, :) = []; % remove them from the list

sorted_zone_list = unique_zone_list(idx);

% Let's assign schools into buildings layer
School_buildings_info = total_specialfac_buildings{1};
bld_id = size(TV0_data_building,1);
bld_id2 = max([TV0_data_building(:).bldID]);
zone_list_id = 0;
for i = 1 : numb_school
    zone_list_id = zone_list_id + 1;
%     if val(zone_list_id) == 0 % If there are no population, go back to max population
%         zone_list_id = 1;
%     end
    zone_list_id = mod(zone_list_id,length(sorted_zone_list));
    if zone_list_id == 0
        zone_list_id = length(sorted_zone_list);
    end
    TV0_data_building(bld_id+i).zoneID = sorted_zone_list(zone_list_id);
    TV0_data_building(bld_id+i).bldID = bld_id2+i; % Building Id
    TV0_data_building(bld_id+i).nHouse = 0;
    TV0_data_building(bld_id+i).residents = 0;
    TV0_data_building(bld_id+i).specialFac = 1; % School
    TV0_data_building(bld_id+i).fptarea = School_buildings_info(i,1);
    TV0_data_building(bld_id+i).nstoreys= School_buildings_info(i,2);
    TV0_data_building(bld_id+i).lrstype = School_buildings_info(i,4);
    TV0_data_building(bld_id+i).CodeLevel = School_buildings_info(i,3);
    TV0_data_building(bld_id+i).OccBld = 'Edu';
    TV0_data_building(bld_id+i).lut_number = [];
    TV0_data_building(bld_id+i).expStr = [lrs_types{TV0_data_building(bld_id+i).lrstype}, '+',...
                                          code_level_types{TV0_data_building(bld_id+i).CodeLevel},'+'...
                                          [num2str(TV0_data_building(bld_id+i).nstoreys) 's'],'+',...
                                          TV0_data_building(bld_id+i).OccBld];
end

% Let's assign hospitals into buildings layer
Hospital_buildings_info = total_specialfac_buildings{2};
bld_id = size(TV0_data_building,1);
bld_id2 = max([TV0_data_building(:).bldID]);
zone_list_id = 0;
for i = 1 : numb_hospital
    zone_list_id = zone_list_id+1;
%     if val(zone_list_id) == 0 % If there are no population, go back to max population
%         zone_list_id = 1;
%     end
    zone_list_id = mod(zone_list_id,length(sorted_zone_list));
    if zone_list_id == 0
        zone_list_id = length(sorted_zone_list);
    end
    TV0_data_building(bld_id+i).zoneID = sorted_zone_list(zone_list_id);
    TV0_data_building(bld_id+i).bldID = bld_id2+i; % Building Id
    TV0_data_building(bld_id+i).nHouse = 0;
    TV0_data_building(bld_id+i).residents = 0;
    TV0_data_building(bld_id+i).specialFac = 2; % Hospital
    TV0_data_building(bld_id+i).fptarea = Hospital_buildings_info(i,1);
    TV0_data_building(bld_id+i).nstoreys= Hospital_buildings_info(i,2);
    TV0_data_building(bld_id+i).lrstype = Hospital_buildings_info(i,4);
    TV0_data_building(bld_id+i).CodeLevel = Hospital_buildings_info(i,3);
    TV0_data_building(bld_id+i).OccBld = 'Hea';
    TV0_data_building(bld_id+i).lut_number = [];
    TV0_data_building(bld_id+i).expStr = [lrs_types{TV0_data_building(bld_id+i).lrstype}, '+',...
                                          code_level_types{TV0_data_building(bld_id+i).CodeLevel},'+'...
                                          [num2str(TV0_data_building(bld_id+i).nstoreys) 's'],'+',...
                                          TV0_data_building(bld_id+i).OccBld];
end

% -------------------------------------------------------------------------
% STEP21 Employement status of the individuals
% -------------------------------------------------------------------------

waitbar(21/26, wb, 'Processing - Step 21');

% Assumption :
% Only 18-65 years old individuals can work (AP5-AP9)

% Employment probability wrt gender by considering only individuals in
% labor force
%               EA1   EA2   EA3   EA4   EA5 
% dist_table13 = [0.05, 0.05, 0.15, 0.10, 0.65; ... % Female
%                 0.05, 0.10, 0.15, 0.20, 0.50];    % Male

dist_table13 = readmatrix(dt_file,'Sheet','Distributions','Range','B88:F89');

% Labor Force
% dist_table12 = [0.86;... % Female
%                 0.89];   % Male

dist_table12 = readmatrix(dt_file,'Sheet','Distributions','Range','B94:B95');

% Find out indices of individuals that can work (AP5-AP9)
individuals_indx_work = and([TV0_data_individual(:).age].' >= readmatrix(dt_file,'Sheet','Assumptions','Range','C38:C38'),...
    [TV0_data_individual(:).age].' <= readmatrix(dt_file,'Sheet','Assumptions','Range','D38:D38'));
individuals_indx_work_male = and([TV0_data_individual(:).gender].' == 2, individuals_indx_work);   % Male
individuals_indx_work_female = and([TV0_data_individual(:).gender].' == 1, individuals_indx_work); % Female
total_female_work_numb = sum(individuals_indx_work_female);
total_male_work_numb = sum(individuals_indx_work_male);

[TV0_data_individual(:).Work] = deal(-1); % Assign all -1
[TV0_data_individual(individuals_indx_work).Work] = deal(1); % Assign only working group 1

female_assign_work = num2cell(rand(total_female_work_numb,1)<dist_table12(1)) ; % Only 0.86% can work, others unemployed
male_assign_work = num2cell(rand(total_male_work_numb,1)<dist_table12(2));    % Only 0.89% can work, others unemployed
[TV0_data_individual(individuals_indx_work_female).Work] = deal(female_assign_work{:}); % wrt Labor Force
[TV0_data_individual(individuals_indx_work_male).Work] = deal(male_assign_work{:});     % wrt Labor Force

% Check individuals Education Attainment Status, and assign work 1 or
% unemployed (0) to individuals that have work property 1 which is
% calculated above.

tv0digender = [TV0_data_individual(:).gender];
tv0dieduas = [TV0_data_individual(:).eduAttStat];

for i= 1: size(dist_table13,2) % For all different education attainment status (for now 5)
    for k = 1:size(dist_table13,1) % For all genders
        individuals_indx_work_new = [TV0_data_individual(:).Work] == 1; % All employed
        individuals_indx_general = all([individuals_indx_work_new, tv0digender ==k, tv0dieduas == i]);
        total_numb = sum(individuals_indx_general);
        if total_numb == 0
            continue;
        end
        assign_work = num2cell(rand(total_numb,1)<dist_table13(k,i)) ;
        [TV0_data_individual(individuals_indx_general).work] = deal(assign_work{:});
    end
end

% -------------------------------------------------------------------------
% STEP22 Assign IndividualFacID
% -------------------------------------------------------------------------

waitbar(22/26, wb, 'Processing - Step 22');

% Assumption : 
% Each individual is working within the total study area extent.
% Each individual (within schooling age limits) goes to school within the total study area extent.
working_places = {'Com','Ind','ResCom'};
working_place_indices = any([strcmp({TV0_data_building(:).OccBld}.','Com') , strcmp({TV0_data_building(:).OccBld}.','Ind') , strcmp({TV0_data_building(:).OccBld}.','ResCom')],2);
building_ids_workplaces = [TV0_data_building(working_place_indices).bldID].';

working_individuals_indices = [TV0_data_individual(:).Work]==1 ; % Working Individuals
total_working_indiv_numb = sum(working_individuals_indices);

assigned_building_ids = building_ids_workplaces(round(1+ (length(building_ids_workplaces)-1)*rand(total_working_indiv_numb,1))) ; % a+(b-a)*rand --> random between [a-b]
temp_building_id = num2cell(assigned_building_ids);
[TV0_data_individual(working_individuals_indices).Work] = deal(temp_building_id{:});

school_place_indices = [TV0_data_building(:).specialFac]==1 ; % School indices
school_building_id = [TV0_data_building(school_place_indices).bldID].'; % Building id of schools
school_individuals_indices = [TV0_data_individual(:).schoolEnrollment]==1 ; % Individuals going to school
total_student_numb = sum(school_individuals_indices);

assigned_building_ids = school_building_id(round(1+(length(school_building_id)-1)*rand(total_student_numb,1))) ; % a+(b-a)*rand --> random between [a-b]
temp_school_bldid = num2cell(assigned_building_ids);
[TV0_data_individual(school_individuals_indices).schoolEnrollment] = deal(temp_school_bldid{:});

% Sum up all information for indivFacID
TV0_data_individual(1).indivFacID = [];
for i=1:size(TV0_data_individual,1)
    if TV0_data_individual(i).schoolEnrollment ~= -1
        TV0_data_individual(i).indivFacID = [TV0_data_individual(i).schoolEnrollment] ;
    elseif TV0_data_individual(i).Work > 0
        TV0_data_individual(i).indivFacID = [TV0_data_individual(i).Work];
    else
        TV0_data_individual(i).indivFacID = -1;
    end
end

% -------------------------------------------------------------------------
% STEP23 CommFacID
% -------------------------------------------------------------------------

waitbar(23/26, wb, 'Processing - Step 23');

% Random assignment (Identify closest facility for each individual in the next version)

TV0_data_household(1).CommFacID = []; % Initialize
hospital_place_indices = [TV0_data_building(:).specialFac]==2 ; % Hospital indices
hospital_building_id = [TV0_data_building(hospital_place_indices).bldID].'; % Building id of hospitals

assigned_building_ids = hospital_building_id(round(1+ (length(hospital_building_id)-1)*rand(size(TV0_data_household,1),1))) ; % a+(b-a)*rand --> random between [a-b]
temp_hospital_bldid = num2cell(assigned_building_ids);
[TV0_data_household(:).CommFacID] = deal(temp_hospital_bldid{:});

% -------------------------------------------------------------------------
% STEP24 Assign repValue
% -------------------------------------------------------------------------

waitbar(24/26, wb, 'Processing - Step 24');

% Assumption :
% Unit price for replacement wrt occupation type and special facility status of the building

% Unit_price = [100; %Res
%               150; %Com
%               140; %Ind
%               170; %ResCom
%               95 ; %Edu
%               135];%Hea

Unit_price = readmatrix(dt_file,'Sheet','Assumptions','Range','C51:H51').';

% occupation_types = {'Res','Com','Ind','ResCom','Edu','Hea'};

occupation_types = readcell(dt_file,'Sheet','Assumptions','Range','C50:H50');

tv0dboccBld = {TV0_data_building(:).OccBld}.';

TV0_data_building(1).repValue =[];
for i=1:length(Unit_price)
    multiplier = Unit_price(i);
    buildings_indx = strcmp(tv0dboccBld, occupation_types{i});
    temp_data = num2cell(([TV0_data_building(buildings_indx).fptarea].'.*[TV0_data_building(buildings_indx).nstoreys].') * multiplier);
    [TV0_data_building(buildings_indx).repValue] = deal(temp_data{:});
end

% Clear out the buildings without zoneID
mask = find(~cellfun(@isempty,{TV0_data_building.zoneID}));
TV0_data_building = TV0_data_building(mask);

%--------------------------------------------------------------------------
% Finished Save Building/Household/Individual Layers
%--------------------------------------------------------------------------

% Clear out some data . (Keep fpt area for buildings for now)
TV0_data_landuse = TV0_data_landuse(:,5:end);
TV0_data_building = rmfield(TV0_data_building, {'lut_number','OccBld','lrstype','CodeLevel','assigned','nstoreys'});
TV0_data_household = rmfield(TV0_data_household,{'income_numb','zoneType','zoneID'});
TV0_data_individual = rmfield(TV0_data_individual,{'schoolEnrollment','Work'});

%Force struct to table format
building_data  = struct2table(TV0_data_building);
% household_data = struct2table(TV0_data_household);
% individual_data = struct2table(TV0_data_individual);

building_data = building_data(randperm(size(building_data, 1)), :); % shuffle buildings

% Save layers into excel file
if ~exist(fullfile(path_luf,"_outputs"), 'dir')
    mkdir(fullfile(path_luf,"_outputs"))
else
    delete (fullfile(path_luf,"_outputs\")+'*.xlsx');
end

% if height(building_data) < 2^20
%     writetable(building_data,fullfile(path_luf,"_outputs\layer_building_initial_list.xlsx"));
% else
%     writetable(building_data,fullfile(path_luf,"_outputs\layer_building_initial_list.csv"));
% end

%% PART II

% -------------------------------------------------------------------------
% STEP25 Create Building Centres and Footprints
% -------------------------------------------------------------------------

waitbar(25/26, wb, 'Processing - Step 25');

bld_lyr = building_data;

idx1 = find(contains(fieldnames(luf), 'zoneID'));
idx2 = find(strcmp(bld_lyr.Properties.VariableNames, 'zoneID'), 1);
idx3 = find(strcmp(bld_lyr.Properties.VariableNames, 'fptarea'), 1);

[binvalues, bingroups] = groupsummary(bld_lyr.(idx3), bld_lyr.(idx2), @sum); % sum of FPs wrt zoneID

%% create final output table

table_final = cell2table(cell(1,size(bld_lyr,2)), 'VariableNames', bld_lyr.Properties.VariableNames);
table_final.xCoord = 0;
table_final.yCoord = 0;
table_final(1,:) = [];
rot_vec = [];

%% start diary

diary processing_report.txt
disp(strcat('Report||',string(datetime)))
disp(' ')

%% iterate polygons

for i = 1:luf_h
	xval = luf(i).X;
	yval = luf(i).Y;
	
	count = 0;
	list1 = [];
	table_ini = cell2table(cell(1,size(bld_lyr,2)), 'VariableNames', bld_lyr.Properties.VariableNames);
	table_ini(1,:) = [];
		
	for ii = 1:length(bld_lyr.(idx2))

		
		if bld_lyr.(idx2)(ii) == luf(i).(subsref(fieldnames(luf),substruct('{}',{idx1})))				
			count = count+1;
			list1(count) = bld_lyr.(idx3)(ii);
			table_ini = [table_ini;bld_lyr(ii,:)];								 
		else
			% pass
		end
	end
	
	%% select data containing polygons

    if  count ~= 0
		
		rot_a = randi([10 40]); % random rotation angle for all building footprints in a polygon
		separation_val = sqrt(max(list1))/cosd(rot_a); % possible minimum distance between building centroids
													   % max sqrt value has to be divided by cosine of rotation angle
                                                       
		boundary_approach = (sqrt(max(list1))/2)*sqrt(2); % buffer distance to polygon boundary
																					   
		[lat_luf,lon_luf] = projinv(prj_luf,luf(i).X,luf(i).Y); % convert to geographical coordinates
		[lat_buf,lon_buf] = bufferm(lat_luf,lon_luf,km2deg(boundary_approach/1000),'in');
		[xbuf,ybuf] = projfwd(prj_luf,lat_buf,lon_buf);
		poly1 = polyshape(xval,yval,'Simplify',false);
		poly2 = polyshape(xbuf,ybuf,'Simplify',false);
		polyfinal = subtract(poly1,poly2);

		xfinal = polyfinal.Vertices(:,1);
		yfinal = polyfinal.Vertices(:,2);

		%% distance-based point assignment
		
		% bounding box
		lower_x = min(xfinal);
		upper_x = max(xfinal);

		lower_y = min(yfinal);
		upper_y = max(yfinal);

		% grid points
		space_x = lower_x:separation_val:upper_x;
		space_y = lower_y:separation_val:upper_y;
		[mg_x, mg_y] = meshgrid(space_x, space_y);

		% filter out exterior points
		masked_points = inpolygon(mg_x(:), mg_y(:), xfinal, yfinal);
		masked_coords = [mg_x(masked_points), mg_y(masked_points)];
        masked_coords = masked_coords(randperm(size(masked_coords, 1)), :); % shuffle coordinate pairs

		% reduce to required number of buildings
		[hip, wip] = size(masked_coords);

        if hip > count
            idx4 = randsample(hip,count); % random point selection
            bld_centres = masked_coords(idx4,:);
            rot_a = zeros(1,size(bld_centres,1)) + rot_a;
            rot_vec = [rot_vec, rot_a];
        elseif hip == count
            bld_centres = masked_coords;
            rot_a = zeros(1,size(bld_centres,1)) + rot_a;
            rot_vec = [rot_vec, rot_a];
        else
            rot_new = 0; % rotation angle for building footprints
            separation_val = sqrt(max(list1))/cosd(rot_new);	% possible minimum distance between building centroids
                                                                % max sqrt value has to be divided by cosine of rotation angle

            separation_val = round(separation_val,2)-0.02; % round to two decimal digits and remove error ~2cm

            % grid points
            space_x = lower_x:separation_val:upper_x;
            space_y = lower_y:separation_val:upper_y;
            [mg_x, mg_y] = meshgrid(space_x, space_y);

            % filter out exterior points
            masked_points = inpolygon(mg_x(:), mg_y(:), xfinal, yfinal);
            masked_coords = [mg_x(masked_points), mg_y(masked_points)];
            masked_coords = masked_coords(randperm(size(masked_coords, 1)), :); % shuffle coordinate pairs

            % reduce to required number of buildings
            [hip, wip] = size(masked_coords);
            
            if hip > count
                idx5 = randsample(hip,count); % random point selection
                bld_centres = masked_coords(idx5,:);
                rot_new = zeros(1,size(bld_centres,1)) + rot_new;
                rot_vec = [rot_vec, rot_new]; % append new rotation value for case 1
            elseif hip == 0
                bld_centres = [];
            else
                bld_centres = masked_coords;
                rot_new = zeros(1,size(bld_centres,1)) + rot_new;
                rot_vec = [rot_vec, rot_new]; % append new rotation value for case 2
            end
            
        end
        
        %xval_nan = xval(:,~isnan(xval)); % remove nan value(s)
        %yval_nan = yval(:,~isnan(yval)); % remove nan value(s)

        comp_zoneID = sprintf('ZoneID = %d',luf(i).(subsref(fieldnames(luf),substruct('{}',{idx1}))));
        disp(comp_zoneID)

        comp_area = sprintf('Total Area of LU Polygon = %.2f ha || Total Area of Requested Building Layer Footprints = %.2f ha',area(poly1)/10000,binvalues(find(bingroups==luf(i).(subsref(fieldnames(luf),substruct('{}',{idx1})))))/10000); % check for total number of buildings in each zone
        disp(comp_area)        

        comp_msg = sprintf('Building Layer Footprints = %d || Created Footprints = %d',count,size(bld_centres,1)); % check for total number of buildings in each zone
        disp(comp_msg)
        disp(' ')
        
        if ~isempty(bld_centres)
            table_ini = table_ini(1:size(bld_centres,1),:);
            table_ini.xCoord = round(bld_centres(:,1),3);
            table_ini.yCoord = round(bld_centres(:,2),3);

            table_final = [table_final; table_ini]; % append zone data at the end of each iteration
        end
		  
    end

end

%% write coordinates included table to excel file
% make fieldnames lowercase
TV0_data_landuse = table2struct(TV0_data_landuse); 
fnames1 = fieldnames(TV0_data_landuse);
TV0_data_landuse = RenameField(TV0_data_landuse, fnames1, lower(fnames1));
TV0_data_landuse = struct2table(TV0_data_landuse);

TV0_data_building = table2struct(table_final);
fnames2 = fieldnames(TV0_data_building);
TV0_data_building = RenameField(TV0_data_building, fnames2, lower(fnames2));
TV0_data_building = struct2table(TV0_data_building);

fnames3 = fieldnames(TV0_data_household);
TV0_data_household = RenameField(TV0_data_household, fnames3, lower(fnames3));
TV0_data_household = struct2table(TV0_data_household);

fnames4 = fieldnames(TV0_data_individual);
TV0_data_individual = RenameField(TV0_data_individual, fnames4, lower(fnames4));
TV0_data_individual = struct2table(TV0_data_individual);

writetable(TV0_data_landuse,fullfile(path_luf,"_outputs\layer_landuse.xlsx"));

% write files 
if height(TV0_data_building) < 2^20
    writetable(TV0_data_building,fullfile(path_luf,"_outputs\layer_building.xlsx"));
else
    writetable(TV0_data_building,fullfile(path_luf,"_outputs\layer_building.csv"));
end

if height(TV0_data_household) < 2^20
    writetable(TV0_data_household,fullfile(path_luf,"_outputs\layer_household.xlsx"));
else
    writetable(TV0_data_household,fullfile(path_luf,"_outputs\layer_household.csv"));
end

if height(TV0_data_individual) < 2^20
    writetable(TV0_data_individual,fullfile(path_luf,'_outputs\layer_individual.xlsx'));
else
    writetable(TV0_data_individual,fullfile(path_luf,'_outputs\layer_individual.csv'));
end

%% create building centres

table_centres = table_final;
table_centres = table2struct(table_centres);
fnames5 = fieldnames(table_centres);
table_centres = RenameField(table_centres, fnames5, lower(fnames5));
[table_centres.('X')] = table_centres.('xcoord');
[table_centres.('Y')] = table_centres.('ycoord');
table_centres = rmfield(table_centres,'xcoord');
table_centres = rmfield(table_centres,'ycoord');

for iii = 1:height(table_final)
	table_centres(iii).Geometry = 'Point';
end

%% create building footprints

for iii = 1:height(table_final)
	buildings(iii) = polybuffer([table_final.xCoord(iii) table_final.yCoord(iii)],'lines',sqrt(double(string(table_final.fptarea(iii))))/2,'JointType','square');
	buildings(iii) = rotate(buildings(iii),-rot_vec(iii),[table_final.xCoord(iii) table_final.yCoord(iii)]); % rotate shapes clockwise
end

table_buildings = table2struct(table_final);
fnames6 = fieldnames(table_buildings);
table_buildings = RenameField(table_buildings, fnames6, lower(fnames6));
[table_buildings.('X')] = table_buildings.('xcoord');
[table_buildings.('Y')] = table_buildings.('ycoord');
table_buildings = rmfield(table_buildings,'xcoord');
table_buildings = rmfield(table_buildings,'ycoord');

for iii = 1:height(table_final)
	table_buildings(iii).Geometry = 'Polygon';
	table_buildings(iii).X = buildings(1,iii).Vertices(:,1);
	table_buildings(iii).Y = buildings(1,iii).Vertices(:,2);
end

disp('Comparison of Total Buildings')
fnl_msg = sprintf('Building Layer = %d || Created Footprints = %d',size(bld_lyr,1),size(table_buildings,1)); % final comparison
disp(fnl_msg)
disp(' ')

tstop = toc(tstrt);
if tstop < 60
    fprintf('Successfully completed in %d sec!\n', round(tstop));
elseif (60 <= tstop) && (tstop < 3600)
    fprintf('Successfully completed in %d min %d sec!\n', floor(tstop/60), round(mod(tstop,60)));
elseif tstop >= 3600
    fprintf('Successfully completed in %d hr %d min %0.0f sec!\n', floor(tstop/3600), floor(rem(tstop,3600)/60), (mod(rem(tstop,3600),60)));
end

diary off
movefile('processing_report.txt', fullfile(path_luf,"_outputs"))

%% export to shapefile
% centre of buildings - point
shapewrite(table_centres, fullfile(path_luf,"_outputs\"+extractBefore(luf_name,".")+"_building_centres"+".shp"))

if isequal(prj_luf.Name, "World_Cylindrical_Equal_Area") % change projection file from 4326 to 54034
    output_prj = fullfile(path_luf,"_outputs\"+extractBefore(luf_name,".")+"_building_centres"+".prj");
    fid2 = fopen(output_prj,'w');
    fprintf(fid2, 'PROJCS["World_Cylindrical_Equal_Area",GEOGCS["GCS_WGS_1984",DATUM["D_WGS_1984",SPHEROID["WGS_1984",6378137.0,298.257223563]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]],PROJECTION["Cylindrical_Equal_Area"],PARAMETER["False_Easting",0.0],PARAMETER["False_Northing",0.0],PARAMETER["Central_Meridian",0.0],PARAMETER["Standard_Parallel_1",0.0],UNIT["Meter",1.0]]');
    fclose(fid2);
else
    copyfile(strcat(path_luf,extractBefore(luf_name,".")+".prj"), fullfile(path_luf,"_outputs\"+extractBefore(luf_name,".")+"_building_centres"+".prj"), 'f'); % add projection file
end  

% building footprints - polygon
shapewrite(table_buildings, fullfile(path_luf,"_outputs\"+extractBefore(luf_name,".")+"_building_footprints"+".shp"))
delete(wb)

if isequal(prj_luf.Name, "World_Cylindrical_Equal_Area") % change projection file from 4326 to 54034
    output_prj = fullfile(path_luf,"_outputs\"+extractBefore(luf_name,".")+"_building_footprints"+".prj");
    fid2 = fopen(output_prj,'w');
    fprintf(fid2, 'PROJCS["World_Cylindrical_Equal_Area",GEOGCS["GCS_WGS_1984",DATUM["D_WGS_1984",SPHEROID["WGS_1984",6378137.0,298.257223563]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]],PROJECTION["Cylindrical_Equal_Area"],PARAMETER["False_Easting",0.0],PARAMETER["False_Northing",0.0],PARAMETER["Central_Meridian",0.0],PARAMETER["Standard_Parallel_1",0.0],UNIT["Meter",1.0]]');
    fclose(fid2);
else
    copyfile(strcat(path_luf,extractBefore(luf_name,".")+".prj"), fullfile(path_luf,"_outputs\"+extractBefore(luf_name,".")+"_building_footprints"+".prj"), 'f'); % add projection file
end      

%%
% -------------------------------------------------------------------------
% STEP26 Visualise building footprints
% -------------------------------------------------------------------------

s = get(0, 'ScreenSize');
figure('Position', [s(3)-s(3)/4-50 50 s(3)/4 s(4)/2]);
mapshow(luf,'facecolor',[1 253/255 208/255])
hold on
mapshow(table_buildings,'facecolor',[1 0.5 0.5])
hold off

%% final messagebox

%h = msgbox(["Process successfully completed!";"Please check your workspace for the outputs.";""],'BuildingXyFpGen');
h = msgbox(["Process successfully completed!";"Please check your workspace for the outputs."],"Data Production");
% h.Position(3:4)=[250,100]; % enlarge box
% ah = get( h, 'CurrentAxes' );
% ch = get( ah, 'Children' );
% set( ch, 'FontSize', 10 ); % enlarge text

%clearvars
disp(' ')
%profile off
%profile viewer

%%
%--------------------------------------------------------------------------
% Functions Used
%--------------------------------------------------------------------------

% Function-1
function building = generate_new_building(lut_number, LRS_Table, nStoreys_Table, fpt_prob, storey_info)
    pd_lrs = makedist('Multinomial','Probabilities',LRS_Table{lut_number});  % LRS Probability distribution
    lrs_val=random(pd_lrs,1,1); % LRS
    pd_nstoreys = makedist('Multinomial','Probabilities',nStoreys_Table{lut_number,lrs_val}); % Number of Storeys distribution
    nstoreys_profile_val=random(pd_nstoreys,1,1); % number of storeys (1-LR 2-MR 3-HR)
    if nstoreys_profile_val==1 % LR
        nstoreys = randi([storey_info(1,1) storey_info(1,2)]); % min max storeys from distribution/assumption file
    elseif nstoreys_profile_val==2 % MR
        nstoreys = randi([storey_info(2,1) storey_info(2,2)]); % min max storeys from distribution/assumption file
    elseif nstoreys_profile_val==3 % HR
        nstoreys = randi([storey_info(3,1) storey_info(3,2)]); % min max storeys from distribution/assumption file
    end
    fptBLD = round(fpt_prob(1) + (fpt_prob(2)-fpt_prob(1)).*rand(1,1));
    building=[ lrs_val, nstoreys , fptBLD];     
end

% Function-2
function column_vector=cumsum2vector(cumsum_vector)
    for j=1:length(cumsum_vector)
        if j==1
            start_num=1;
        else
            start_num = cumsum_vector(j-1)+1; 
        end
        end_num = cumsum_vector(j);
        column_vector(start_num:end_num)=j;
    end
    column_vector = column_vector(:);
end

% Function-3
% Author: Jan Simon, Heidelberg, (C) 2006-2022 matlab.2010(a)n(MINUS)simon.de
function S = RenameField(S, Old, New)

if isempty(S) && isa(S, 'double')  % Accept [] as empty struct without fields
   return;
end

Data  = struct2cell(S);
Field = fieldnames(S);
if ischar(Old)
   Field(strcmp(Field, Old)) = {New};

elseif iscellstr(Old)   %#ok<ISCLSTR>
   for iField = 1:numel(Old)
      match = strcmp(Field, Old{iField});
      if any(match)
         Field{match} = New{iField};
      end
   end
   
elseif isa(Old, 'string')
   for iField = 1:numel(Old)
      match = strcmp(Field, Old(iField));
      if any(match)
         Field{match} = char(New(iField));
      end
   end
   
else
   error(['JSimon:', mfilename, ':BadInputType'], ...
      '*** %s: Names must be CHAR vectors, cell strings or strings!', ...
      mfilename);
end

S = cell2struct(Data, Field);
end

%%%%% GRAND FINALE %%%%%