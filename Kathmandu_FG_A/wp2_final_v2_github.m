
% Author : G Durusoy
% E Mail : goktekindurusoy@gmail.com
% Date   : 28 Oct. 2022
% Version: V2

% Updates wrt versions can be written in here:
% 

%% Clear out the Workspace and Command Window
clear; clc;

%% Input File Folder 
input_file_folder = 'C:\Kandilli Projects\tomorrow_cities\RandomAssignments\Codes\Kathmandu\Kathmandu_FG_A\';

% Read Landuse File
TV0_data_landuse = readtable( [ input_file_folder 'LandUse_FG_A.dbf'], "FileType","spreadsheet");
% TV0_data_landuse2 = readtable( [ input_file_folder2 'LANDUSE_S0\LANDUSE_S0.dbf'], "FileType","spreadsheet");

% TV0_data_landuse lUf needed to be changed to LuT
TV0_data_landuse.Properties.VariableNames{2} = 'LuF';
TV0_data_landuse.Properties.VariableNames{3} = 'densityCap';
TV0_data_landuse.population = str2double([TV0_data_landuse.population]);
TV0_data_landuse.population(isnan(TV0_data_landuse.population))=0;
TV0_data_landuse.zoneID = str2double([TV0_data_landuse.zoneID]);
TV0_data_landuse.densityCap(isnan(TV0_data_landuse.densityCap))=0;

% Preprocessing on land use data
% Type section does not have LowIncome A or B so change those column such
% that 50% of lowIncome become LowIncomeA and others LowIncomeB randomly.
% lowincome_indx=strcmp(TV0_data_landuse.type,'lowIncome');
% income_mat = {'lowIncomeA','lowincomeB'};
% assigned_vals = cell(sum(lowincome_indx),1);
% for i=1:sum(lowincome_indx)    
%     if i> (sum(lowincome_indx)/2)
%         assigned_vals(i)={'lowIncomeA'};
%     else
%         assigned_vals(i)={'lowIncomeB'};
%     end
% end
% new_idx=randperm(sum(lowincome_indx));
% TV0_data_landuse.type(lowincome_indx) =assigned_vals(new_idx); 

avg_income_types = {'lowIncomeA','lowIncomeB','midIncome','highIncome'};
%% All Steps 

% -------------------------------------------------------------------------
% STEP1
% -------------------------------------------------------------------------


% user_percentage = 0.8; % 80% of the max available population will be generated
% max_new_population =(densityCap- population/zone_area)*zone_area; % Calculate max available population
% new_population = max_new_population*percantage; % Find out new population

% This step is not used exactly as it is because of the input landuse layer
% file. Therefore new population will be obtained by using without the area
% column in the Landuse layer dbf file. 

% For All Zone-IDs
area = TV0_data_landuse.area;   % Area should be known

nPeople = round(TV0_data_landuse.densityCap.*area - TV0_data_landuse.population);
nPeople(nPeople<0)=0; % Negative populations become 0;

% If average income is empty, clear out the population 
nPeople(cellfun(@isempty, TV0_data_landuse.avgIncome))=0;


% -------------------------------------------------------------------------
% STEP2 Identify the number of households
% -------------------------------------------------------------------------
% Assumption : 
% Household size distribution is same for different income types

% Individuals in a household (Table-1)
dist_table1 = [1   , 2, 3   , 4   , 5   , 6  , 7  , 8  , 9 ; ... % Number of individual in a household
               22.4, 6, 11.3, 23.7, 14.9, 8.3, 3.2, 3.2, 7];     % Probability of having X people in a household (before dividing by the total number)

household_prop=dist_table1(2,:)/sum(dist_table1(2,:)); % The probability of X number of people living in a household 
nHouse = round(nPeople /(sum(household_prop.*dist_table1(1,:)))); % Total number of households for all zones
k=0;
TV0_data_household =struct('hhID',[],'zoneID',[],'zoneType',[]);
for zone_idx = 1:size(TV0_data_landuse,1) % For every zone in Landuse Layer
    if nHouse(zone_idx)==0
        disp(['there are no populations in the zone id: ' num2str(TV0_data_landuse.zoneID(zone_idx)) ] );
        continue;
    end
    for i= 1:nHouse(zone_idx) 
        k=k+1;
        TV0_data_household(k,1).hhID = k; % Household Id
        TV0_data_household(k,1).zoneID = TV0_data_landuse.zoneID(zone_idx); % Passive, keep it for future purposes
        TV0_data_household(k,1).zoneType = TV0_data_landuse.avgIncome(zone_idx); % Passive, keep it for future purposes
    end
end

% -------------------------------------------------------------------------
% STEP3 Identify the household size and assign "nInd" values to each household
% -------------------------------------------------------------------------
% Assumption : 
% Household size distribution is same for different income types

TV0_data_household(1).nInd = []; % Initialize
% Do it for every zone
for zone_idx = 1:size(TV0_data_landuse,1) % For every zone in Landuse Layer
    if nHouse(zone_idx)==0
%         disp(['there are no populations in the zone id: ' num2str(TV0_data_landuse.id(zone_idx)) ] );
        continue;
    end
    % Find Total of every different nInd number for households
    household_num = (nHouse(zone_idx) * household_prop);
    % Find the cumulative sum
    cumsum_household_num = round(cumsum(household_num,2));
    % Make it a column vector
    column_vector=cumsum2vector(cumsum_household_num);
    % Randomly permute the nInd
    sample_idx = randperm(length(column_vector));
    % Assign randomly permuted nInd into households
    temp_indx=[TV0_data_household(:).zoneID]==TV0_data_landuse.zoneID(zone_idx);
    temp_indx = temp_indx(:); % force it to be a column vector
    temp_numb = num2cell(column_vector(sample_idx));
    [TV0_data_household(temp_indx).nInd] = deal(temp_numb{:});
end


% -------------------------------------------------------------------------
% STEP4 Identify and assign income type of the households
% -------------------------------------------------------------------------

% % Avg Income Dist. Tables (Table-2)
% % Households  LIA   LIB  MI   HI
dist_table2={[0.60 0.30 0.10 0   ];...       % LIA (Zone)
             [0.35 0.50 0.15 0   ];...       % LIB (Zone)
             [0.05 0.10 0.80 0.05];...       % MI  (Zone)
             [0    0    0.15 0.85]};         % HI  (Zone)


TV0_data_household(1).income_numb = []; % Initialize ( keep it as a number 1-lowIncomeA, 2-lowIncomeB, 3-midIncome, 4-highIncome
TV0_data_household(1).income = []; % Initialize
for i = 1: length(avg_income_types)
    % Get total number of households wrt income type of zone.
    income_idx=strcmp([TV0_data_household(:).zoneType],avg_income_types{i});
    income_idx = income_idx(:); % force it to be a column vector
    % Find Total of every different income type
    income_of_households=dist_table2{i}*sum(income_idx);
    % Find the cumulative sum  
    cumsum_household_num = round(cumsum(income_of_households));
    % Make it a column vector
    column_vector=cumsum2vector(cumsum_household_num);
    % Randomly permute the average income types
    sample_idx = randperm(length(column_vector));
    % Assign randomly permuted average income types into households
    temp_numb = num2cell(column_vector(sample_idx));
    temp_str =  {avg_income_types{column_vector(sample_idx)}};    
    [TV0_data_household(income_idx).income_numb] = deal(temp_numb{:}); 
    [TV0_data_household(income_idx).income] = deal(temp_str{:});
end

% -------------------------------------------------------------------------
% STEP5 Identify and assign a unique ID for each  individual
% -------------------------------------------------------------------------

TV0_data_individual =struct('hhID',[],'indivId',[]);
k=0;
for hh_idx = 1:size(TV0_data_household,1) % For every household in Household Layer    
    for i= 1:TV0_data_household(hh_idx).nInd     
        k=k+1;
        TV0_data_individual(k,1).indivId = k; % Individual Id               
    end
end

% -------------------------------------------------------------------------
% STEP6 Identify and assign gender for each individual
% -------------------------------------------------------------------------
% Assumption :
% Gender distribution is same for different income types 

% Gender (Meta Data)
% 1 - Female
% 2 - Male

% Gender Dist. Table (Table-3)
%            F   M 
dist_table3=[0.5 0.5];

TV0_data_individual(1).gender = []; % Initialize
n_total_people = size(TV0_data_individual,1);
% Find Total number of individuals of different gender
gender_of_individuals=dist_table3*n_total_people;
% Find the cumulative sum  
cumsum_gender_num = round(cumsum(gender_of_individuals));
% Make it a column vector
column_vector=cumsum2vector(cumsum_gender_num);
% Randomly permute the gender on individuals
sample_idx = randperm(length(column_vector));
% Assign randomly permuted gender types into individuals
temp_numb = num2cell(column_vector(sample_idx));    
[TV0_data_individual(:).gender] = deal(temp_numb{:}); 


% -------------------------------------------------------------------------
% STEP7 Identify and assign age for each individual
% -------------------------------------------------------------------------
% Assumption :
% Age profile is same for different income types

% Age Profile (Meta Data)
% 1 - 00-05  
% 2 - 05-15  
% 3 - 15-18  
% 4 - 18-20  
% 5 - 20-25  
% 6 - 25-30
% 7 - 30-40 
% 8 - 40-50  
% 9 - 50-65  
% 10- 65+.   	
%
% Age Profile with respect to gender
%   | AP1  | AP2  | AP3  | AP4  | AP5  | AP6  | AP7  | AP8  | AP9  | AP10
% F |0.005 |0.0140|0.0510|0.0880|0.0220|0.1020|0.0680|0.1900|0.1700|0.2900|
% M |0.005 |0.0165|0.0606|0.1040|0.0262|0.1030|0.0686|0.2020|0.1616|0.2525|

dist_table4 = {[0.005 0.0140 0.0510 0.0880 0.0220 0.1020 0.0680 0.1900 0.1700 0.2900];... % Female
               [0.005 0.0165 0.0606 0.1040 0.0262 0.1030 0.0686 0.2020 0.1616 0.2525]};   % Male


TV0_data_individual(1).age = []; % Initialize
for gender_id =1:2
    % Get total number of individuals wrt gender.
    gender_idx = [TV0_data_individual(:).gender]== gender_id;
    gender_idx = gender_idx(:); % force it to be a column vector
    % Find Total number of individuals for different age
    age_of_individuals = dist_table4{gender_id}*sum(gender_idx);
    % Find the cumulative sum  
    cumsum_age_num = round(cumsum(age_of_individuals));
    % Make it a column vector
    column_vector=cumsum2vector(cumsum_age_num);
    % Randomly permute the age profiles of individuals
    sample_idx = randperm(length(column_vector));
    % Assign randomly permuted age profiles into individuals
    temp_numb = num2cell(column_vector(sample_idx));   
    [TV0_data_individual(gender_idx).age] = deal(temp_numb{:}); 
end

% -------------------------------------------------------------------------
% STEP8 Identify and assign education attainment status for each individual
% -------------------------------------------------------------------------
% Assumption :
% Education Attainment status is same for different income types 

% Education Attainment Status (Meta Data)
% 1 - Only literate
% 2 - Primary school
% 3 - Elementary sch.
% 4 - High school
% 5 - University and above

dist_table5 = {[0.05 0.140 0.1510 0.1880 0.4710];... % Female
               [0.05 0.165 0.1606 0.1040 0.5204]};   % Male

TV0_data_individual(1).eduAttStat = []; % Initialize
for gender_id =1:2
    % Get total number of individuals wrt gender.
    gender_idx = [TV0_data_individual(:).gender]== gender_id;
    gender_idx = gender_idx(:); % force it to be a column vector
    % Find Total number of individuals for different eduAttStat
    eduattstatus_of_individuals = dist_table5{gender_id}*sum(gender_idx);
    % Find the cumulative sum  
    cumsum_edu_num = round(cumsum(eduattstatus_of_individuals));
    % Make it a column vector
    column_vector=cumsum2vector(cumsum_edu_num);
    % Randomly permute the education attainment status
    sample_idx = randperm(length(column_vector));
    % Assign randomly permuted education attainment status into individuals
    temp_numb = num2cell(column_vector(sample_idx));   
    [TV0_data_individual(gender_idx).eduAttStat] = deal(temp_numb{:}); 
end

% -------------------------------------------------------------------------
% STEP9 Identify and assign the head of household to corresponding hhID
% -------------------------------------------------------------------------
% Assumption :
% Head of household is dependent to gender 
% Only (age>20) can be head of households

% Head of Household
dist_table6= [0.23;  % Female
              0.77]; % Male 

[TV0_data_individual(:).head] = deal(0); % Initialize

% Number of  household head 
n_headofhousehold = size(TV0_data_household,1);
total_cumsum=round(cumsum(dist_table6*n_headofhousehold)); % Total female household head, and male household head
% Make it a column vector
column_vector=cumsum2vector(total_cumsum);
% Randomly permute the gender of household heads
sample_idx = randperm(length(column_vector));
% Assign randomly permuted household heads into temporary location
temp_numb = column_vector(sample_idx);   
male_head_household_numb = sum(temp_numb==2); % total number of households with male household head
female_head_household_numb = sum(temp_numb==1); % total number of households with female household head

age_indx = [TV0_data_individual(:).age]>4 ; % Find individuals with age bigger than 20
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

% -------------------------------------------------------------------------
% STEP10 Identify and assign the household that each individual belongs to
% (others than head of households)
% -------------------------------------------------------------------------
% Assumption :
% In relation with Assumption in Step 9, no individuals under 20 years of
% age can live alone in an household.

for i = 1: size(TV0_data_household,1)
    individual_numb = TV0_data_household(i).nInd;
    if individual_numb>1
        % Find out possible candidates and assign      
        empty_hhid_individuals_idx = cellfun(@isempty, {TV0_data_individual(:).hhID}.');
        possible_individuals = find(empty_hhid_individuals_idx);
        rand_index_hhid = randperm(size(possible_individuals,1),individual_numb-1);
        [TV0_data_individual(possible_individuals(rand_index_hhid)).hhID] = deal(TV0_data_household(i).hhID);
    end

end

% -------------------------------------------------------------------------
% STEP10a Identify school enrollment for each individual
% -------------------------------------------------------------------------
% Assumption :
% Schooling age limits : AP2 and AP3 can go to school


% School Enrollment
%                EA1|EA2|EA3|EA4|EA5
dist_table5a = {[0.7 0.7 0.7 0.8 0.8];...   % lowIncome
                [0.7 0.8 0.8 0.9 1.0];...   % midIncome
                [0.8 0.9 1.0 1.0 1.0]};     % highIncome

schoolEnrollment = -1*ones(size(TV0_data_individual,1),1); % assign all schoolenrollment to -1 for initialization

age_indx_total = or([TV0_data_individual(:).age]==3 , [TV0_data_individual(:).age]==2) ; % Find individuals with age between 5-18
age_indx_total = age_indx_total(:); % Force to be a column vector
indivID_ofstudents = find(age_indx_total); % individual Id of students
hhID_ofstudents = [TV0_data_individual(age_indx_total).hhID].'; % household Id of students
head_eduattstat = zeros(size(hhID_ofstudents,1),1); % Initialize
income_type = zeros(size(hhID_ofstudents,1),1); % Initialize
for i=1:length(hhID_ofstudents)    
    temp_hhid = hhID_ofstudents(i); % temporary household id of students
    hh_id_index = [TV0_data_individual(:).hhID].' == temp_hhid; % Individual indx of temporary household id 
    temp_indiv = TV0_data_individual(hh_id_index);  % Individuals in same household
    head_eduattstat(i,1)=temp_indiv([TV0_data_individual(hh_id_index).head].'==1).eduAttStat; % eduAtt status of head of household
    income_type (i) = TV0_data_household([TV0_data_household(:).hhID].'== temp_hhid).income_numb; % income type of household 
end

% Combine all info
%                     Household id    | Individual ID    | EduAttStat of Head| Income of Household
total_student_info = [hhID_ofstudents ,indivID_ofstudents , head_eduattstat , income_type]; 

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
        column_vector=cumsum2vector(cumsum_school_num)-1; % To force it 0 and 1, 0 not going, 1 going to school        
        % Randomly permute the school status
        sample_idx = randperm(length(column_vector));
        % Assign randomly permuted school status into individuals         
        total_student_info(indx_students,5)=column_vector(sample_idx);
    end
end
[TV0_data_individual(:).schoolEnrollment] = deal(-1); % assign all schoolenrollment to -1 for initialization
temp_school_enroll =num2cell(total_student_info(:,5));
[TV0_data_individual(total_student_info(:,2)).schoolEnrollment] = deal(temp_school_enroll{:}); % Assign schoolenrollment to individuals
save('wp2_step10.mat');
% -------------------------------------------------------------------------
% STEP11 Identify total residential building area
% -------------------------------------------------------------------------

% Average dwelling area (sqm) wrt income type (44 for LI, 54 for MI, 67 for HI in Tomorrovwille)
% Range of footprint area (sqm) wrt. Income type (32-66 for LI, 32-78 for MI and 70-132 for HI in Tomorrowville)

% 
%                       LIA LIB MI HI
Average_dwelling_area = [44 44  54 67];
totalbldarea_res = zeros (size(TV0_data_landuse,1),1); % Initialize
for zone_idx = 1: size(TV0_data_landuse,1)
    zoneid = TV0_data_landuse.zoneID(zone_idx);
    if nHouse(zone_idx)==0
        continue;
    end 
    income_type_households = [TV0_data_household([TV0_data_household(:).zoneID].' == zoneid).income_numb].' ; % Income type of specific zoneID 
    totalbldarea_res(zone_idx) = sum(Average_dwelling_area(income_type_households)); % Keep it for future purposes.
end


% -------------------------------------------------------------------------
% STEP12 Identify number of residential buildings and generate building layer
% -------------------------------------------------------------------------
% Assumptions : 
% Average dwelling area (sqm) wrt income type (44 for LI, 54 for MI, 67 for HI in Tomorrovwille)
% Range of footprint area (sqm) wrt. Income type (32-66 for LI, 32-78 for MI and 70-132 for HI in Tomorrowville)
fpt_area = {[32 66];... % lowIncomeA
            [32 66];... % lowIncomeB
            [32 78];... % midIncome
            [70 132]};  % highIncome

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

land_use_types = unique(TV0_data_landuse.LuF);
land_use_types(cellfun(@isempty ,land_use_types))=[]; % If there are any blank lut type

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
lrs_types = {'BrCfl','BrCri','BrM','Adb','RCi'};


%              |   LRS1    |    LRS2     |    LRS3     |    LRS4     |    LRS5     |
%              |LR | MR| HR|  LR | MR| HR|  LR | MR| HR|  LR| MR | HR|  LR| MR|  HR|
dist_table7 = {[0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2];...    % LUT1
               [0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2];...    % LUT2
               [0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2];...    % LUT3
               [0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2];...    % LUT4
               [0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2];...    % LUT5
               [0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2];...    % LUT6
               [0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2]};    % LUT7
%                [0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2];...    % LUT8
%                [0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2];...    % LUT9
%                [0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2];...    % LUT10
%                [0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2];...    % LUT11
%                [0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2],[0.4 0.4 0.2]};      % LUT12


%              |LRS1|LRS2|LRS3|LRS4|LRS5|
dist_table8 = {[0.15 0.25 0.25 0.15 0.20];...   % LUT1
               [0.15 0.25 0.25 0.15 0.20];...   % LUT2
               [0.15 0.25 0.25 0.15 0.20];...   % LUT3
               [0.15 0.25 0.25 0.15 0.20];...   % LUT4
               [0.15 0.25 0.25 0.15 0.20];...   % LUT5
               [0.15 0.25 0.25 0.15 0.20];...   % LUT6
               [0.15 0.25 0.25 0.15 0.20]};   % LUT7
%                [0.15 0.25 0.25 0.15 0.20];...   % LUT8
%                [0.15 0.25 0.25 0.15 0.20];...   % LUT9
%                [0.15 0.25 0.25 0.15 0.20];...   % LUT10
%                [0.15 0.25 0.25 0.15 0.20];...   % LUT11
%                [0.15 0.25 0.25 0.15 0.20]};     % LUT12

TV0_data_household(1).bldID = []; % Initialize    
TV0_data_building = struct('zoneID',[],'bldID',[],'nHouse',[],'residents',[],...
    'specialFac',[],'expStr', [],'fptarea',[],'nstoreys',[],'lrstype',[],'assigned',[],'lut_number',[]);
bld_numb = 0;
for zone_idx = 1: size(TV0_data_landuse,1) 
    zoneid = TV0_data_landuse.zoneID(zone_idx);
    lut = TV0_data_landuse.LuF(zone_idx);
    avg_income = TV0_data_landuse.avgIncome(zone_idx);
    lut_number = find(strcmp(land_use_types,lut));
    income_number = find(strcmp(avg_income_types,avg_income));
    if totalbldarea_res(zone_idx)==0 % if there are no residential buildings skip it.
        continue;
    end    
    total_generated_bld_area = 0;
    flag = true;    
    while flag
        % find out a building        
        building = generate_new_building(lut_number,dist_table8,dist_table7, fpt_area{income_number});
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
            temp_households_indx = [TV0_data_household(:).zoneID].'== zoneid;
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
                            TV0_data_household([TV0_data_household(:).hhID].'==households_tobe_assigned(indx).hhID).bldID = buildings_tobe_assigned(bld_id).bldID;
                            TV0_data_building([TV0_data_building(:).bldID].'== buildings_tobe_assigned(bld_id).bldID).assigned =1;  % Do not assign anymore                                                      
                        end
                        if bld_total_area<min(Average_dwelling_area)
                            break;
                        end
                    end
                    temp_households_indx = [TV0_data_household(:).zoneID].'== zoneid;
                    temp_household_data_wrt_zone = TV0_data_household(temp_households_indx);
                    empty_bldid_households_idx = cellfun(@isempty, {temp_household_data_wrt_zone(:).bldID}.'); % Find out households with empty bldID
                    households_tobe_assigned=temp_household_data_wrt_zone(empty_bldid_households_idx);
                end
            end
        end
    end
end
% Clear out the buildings without any households
bld_numb_indx = [TV0_data_building(:).assigned].'==0;
TV0_data_building(bld_numb_indx) = [];

% -------------------------------------------------------------------------
% STEP13 Identify and assign occupation attribute and SpecialFac status for residential buildings
% -------------------------------------------------------------------------

TV0_data_building(1).OccBld = [];
% Sum up household and building layer data, findout nHouse and residents
for i = 1: size(TV0_data_building,1)    
    TV0_data_building(i).specialFac = 0;
    TV0_data_building(i).OccBld = 'Res';
end

% -------------------------------------------------------------------------
% STEP14 Identify and assign code level for residential buildings
% -------------------------------------------------------------------------


% Code Level Types
% 1 - LC
% 2 - MC
% 3 - HC
code_level_types = {'LC', 'MC', 'HC'};
%              |   LRS1    |    LRS2     |    LRS3     |    LRS4     |    LRS5     |
%              |LC | MC| HC|  LC | MC| HC|  LC | MC| HC|  LC | MC| HC|  LC | MC| HC|
dist_table11 ={[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1];...    % LUT1
               [0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1];...    % LUT2
               [0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1];...    % LUT3
               [0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1];...    % LUT4
               [0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1];...    % LUT5
               [0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1];...    % LUT6
               [0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1]};    % LUT7
%                [0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1];...    % LUT8
%                [0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1];...    % LUT9
%                [0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1];...    % LUT10
%                [0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1];...    % LUT11
%                [0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1],[0.7 0.2 0.1]};      % LUT12


TV0_data_building(1).CodeLevel = []; % Initialize
for lrs_indx = 1:length(lrs_types)
    for lut_indx = 1:length(land_use_types)

        code_level_prob = dist_table11{lut_indx,lrs_indx};
        temp_building_indx = and( [TV0_data_building(:).lrstype].' == lrs_indx , [TV0_data_building(:).lut_number].' == lut_indx );
        % Find Total number of buildings for different lrs types and lut
        % numbers
        codelevel_of_buildings = dist_table11{lut_indx,lrs_indx}*sum(temp_building_indx);
        % Find the cumulative sum  
        cumsum_cl_num = round(cumsum(codelevel_of_buildings));
        % Make it a column vector
        column_vector=cumsum2vector(cumsum_cl_num);
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

% Sum up household and building layer data, findout nHouse and residents
for i = 1: size(TV0_data_building,1)
    temp_indx = [TV0_data_household(:).bldID].' == TV0_data_building(i).bldID ;
    temp_nHouse = sum(temp_indx); 
    temp_residents = sum([TV0_data_household(temp_indx).nInd].');
    TV0_data_building(i).nHouse = temp_nHouse;
    TV0_data_building(i).residents = temp_residents;
end
save('wp2_step16.mat');
% -------------------------------------------------------------------------
% STEP17 Identify and generate commercial and industrial buildings
% -------------------------------------------------------------------------
% Assumption : 
% Nr of commercial buildings per 1000 individuals
% Nr of industrial buildings per 1000 individuals

numb_com = 5;
numb_ind = 1;

total_individuals = sum([TV0_data_building(:).residents].');

%               Res Ind Com ResCom
dist_table9 = {[1.0 0.0 0.0 0.0];... % LUT1 'AGRICULTURE'
               [0.0 0.0 1.0 0.0];... % LUT2 'CITY CENTER' 
               [0.0 0.0 1.0 0.0];... % LUT3 'COMMERCIAL AND RESIDENTIAL'
               [0.6 0.0 0.3 0.1];... % LUT4 'HISTORICAL PRESERVATION AREA'
               [0.0 1.0 0.0 0.0];... % LUT5 'INDUSTRY'
               [0.0 1.0 0.0 0.0];... % LUT6 'NEW DEVELOPMENT'
               [0.7 0.0 0.1 0.2]};   % LUT7 'NEW PLANNING' 
%                [0.6 0.0 0.1 0.3];... % LUT8 'RECREATION AREA'
%                [0.5 0.0 0.4 0.1];... % LUT9 'RESIDENTIAL (GATED NEIGHBORHOOD)'
%                [0.7 0.0 0.1 0.2];... % LUT10 'RESIDENTIAL (HIGH DENSITY)'
%                [0.6 0.0 0.1 0.3];... % LUT11 'RESIDENTIAL (LOW DENSITY)' 
%                [0.5 0.0 0.4 0.1]};   % LUT12 'RESIDENTIAL (MODERATE DENSITY)'          


% Initialize
total_ind_prob = 0;
total_com_prob = 0;
numb_res = zeros(length(land_use_types),1); 
temp_numb_ind = zeros(length(land_use_types),1);
temp_numb_com = zeros(length(land_use_types),1);
temp_numb_rescom = zeros(length(land_use_types),1);

for lut_indx = 1:length(land_use_types)
    building_occ_prob = dist_table9{lut_indx};    
    if building_occ_prob(1)>0 % If there are residential buildings
        temp_building_indx = [TV0_data_building(:).lut_number].' == lut_indx;
        numb_res(lut_indx) = sum(temp_building_indx); % Find Total number of buildings (Residential) for different lut numbers        
        temp_numb_ind(lut_indx) = round((numb_res(lut_indx)*building_occ_prob(2))/(building_occ_prob(1)+building_occ_prob(4)));       
        temp_numb_com(lut_indx) = round((numb_res(lut_indx)*building_occ_prob(3))/(building_occ_prob(1)+building_occ_prob(4)));
        temp_numb_rescom(lut_indx) = round((numb_res(lut_indx)*building_occ_prob(4))/(building_occ_prob(1)+building_occ_prob(4))); % Total number of rescom buildings
    else
        total_ind_prob = total_ind_prob + building_occ_prob(2);
        total_com_prob = total_com_prob + building_occ_prob(3);   
    end
end

max_ind_buildings = round((total_individuals*numb_ind )/1000); % Find out max industrial buildings
max_com_buildings = round((total_individuals*numb_com )/1000); % Find out max commercial buildings

% If there are problems warn the user
if sum(temp_numb_ind) >= max_ind_buildings 
    warndlg('Revise the number of "ind" buildings or the distribution probabilities in relevant tables','!!!ERROR!!!')
    return;
end
if sum(temp_numb_com) >= max_com_buildings
    warndlg('Revise the number of "com" buildings or the distribution probabilities in relevant tables','!!!ERROR!!!')
    return;
end

% Calculate generated commercial and industrial buildings
generated_buildings_com = max_com_buildings - sum(temp_numb_com) ; % this difference will be generated in other LUTs wrt dist_table9
generated_buildings_ind = max_ind_buildings - sum(temp_numb_ind) ;


% Lut number of Com buildings 
table9 = cell2mat(dist_table9);
Com_Table = table9(:,3) .* double(table9(:,1)==0);
Com_prob = Com_Table/sum(Com_Table);
com_buildings_new= Com_prob*generated_buildings_com;
com_buildings_total = com_buildings_new + temp_numb_com;
 % Find the cumulative sum  
cumsum_combuildings_num = round(cumsum(com_buildings_total));
% Make it a column vector
column_vector=cumsum2vector(cumsum_combuildings_num);
% Randomly permute the code level status
sample_idx = randperm(length(column_vector));
% Assign randomly permuted code level into buildings
com_buildings_lut_numb = column_vector(sample_idx);

% Lut number of Ind Buildings
table9 = cell2mat(dist_table9);
Ind_Table = table9(:,2) .* double(table9(:,1)==0);
Ind_prob = Ind_Table/sum(Ind_Table);
ind_buildings_new= Ind_prob*generated_buildings_ind;
ind_buildings_total = ind_buildings_new + temp_numb_ind;
 % Find the cumulative sum  
cumsum_indbuildings_num = round(cumsum(ind_buildings_total));
% Make it a column vector
column_vector=cumsum2vector(cumsum_indbuildings_num);
% Randomly permute the code level status
sample_idx = randperm(length(column_vector));
% Assign randomly permuted code level into buildings
ind_buildings_lut_numb = column_vector(sample_idx);





% Some of the Res buildings have changed with Res+Com, 
% The numbers of the changes are kept in temp_numb_rescom, 
% Res+Com will be assigned randomly.
for lut_indx = 1:length(land_use_types)
    if temp_numb_rescom(lut_indx)~=0
        temp_building_indx = [TV0_data_building(:).lut_number].' == lut_indx;
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

%               FPT-Range Ns     Code Level    LRS Type
dist_table10 = {[95 150]  [5 10] [0.2 0.5 0.3] [0.1 0.3 0.2 0.3 0.1];... % Com
                [85 105]  [5 10] [0.2 0.4 0.4] [0.1 0.3 0.2 0.3 0.1]};   % Ind


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
    column_vector=cumsum2vector(cumsum_codelevel_num);
    % Randomly permute the code level status
    sample_idx = randperm(length(column_vector));
    % Assign randomly permuted code level into buildings
    code_level_numb = column_vector(sample_idx);

    % Find Total number of buildings for different lrs
    lrs_of_buildings = temp_lrs_type*total_bld_numb;
    % Find the cumulative sum  
    cumsum_lrs_num = round(cumsum(lrs_of_buildings));
    % Make it a column vector
    column_vector=cumsum2vector(cumsum_lrs_num);
    % Randomly permute the code level status
    sample_idx = randperm(length(column_vector));
    % Assign randomly permuted code level into buildings
    lrs_numb = column_vector(sample_idx);
    
    total_com_ind_buildings(i) = {[fpt_numb, n_storeys_numb,code_level_numb,lrs_numb]};
end


% Sum up all buildings files together

Com_buildings_numb = size(total_com_ind_buildings{1},1);
bld_id = size(TV0_data_building,1);
bld_id2 = max([TV0_data_building(:).bldID]); 
Commercial_buildings_info = total_com_ind_buildings{1};
for i = 1 : Com_buildings_numb
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
        lut_number(zone_idx) = find(strcmp(land_use_types,lut));
    else
        lut_number(zone_idx) = 0;
    end
end

% Assing zone id randomly, by controlling their Lut number
empty_zoneid_buildings_idx = cellfun(@isempty, {TV0_data_building(:).zoneID}.');
all_buildings_without_zoneid = TV0_data_building(empty_zoneid_buildings_idx) ;
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
        TV0_data_building([TV0_data_building(:).bldID].'== building_ids(k)).zoneID = zone_ids(k);
    end
end


% -------------------------------------------------------------------------
% STEP19 Generate school and hospitals
% -------------------------------------------------------------------------
% Assumption : 
% 1 school per 10.000 individuals
% 1 hospital per 25.000 individuals

total_individuals = sum([TV0_data_building(:).residents].');
numb_school =  round(total_individuals/10000); % School specialFac=1
numb_hospital = round(total_individuals/25000); % Hospital specialFac=2
if numb_hospital==0
    numb_hospital=1;
end
if numb_school==0
    numb_school=1;
end
% -------------------------------------------------------------------------
% STEP20 Generate expStr for schools and hospitals
% -------------------------------------------------------------------------

%               FPT-Range Ns     Code Level    LRS Type
dist_table14 = {[95 150]  [5 10] [0.2 0.5 0.3] [0.1 0.3 0.2 0.3 0.1];... % School
                [85 105]  [5 10] [0.2 0.4 0.4] [0.1 0.3 0.2 0.3 0.1]};   % Hospital


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
    % Find Total number of buildings for different code level
    codellevel_of_buildings = temp_code_level*total_bld_numb;
    % Find the cumulative sum  
    cumsum_codelevel_num = round(cumsum(codellevel_of_buildings));
    % Make it a column vector
    column_vector=cumsum2vector(cumsum_codelevel_num);
    % Randomly permute the code level status
    sample_idx = randperm(length(column_vector));
    % Assign randomly permuted code level into buildings
    code_level_numb = column_vector(sample_idx);

    % Find Total number of buildings for different lrs
    lrs_of_buildings = temp_lrs_type*total_bld_numb;
    % Find the cumulative sum  
    cumsum_lrs_num = round(cumsum(lrs_of_buildings));
    % Make it a column vector
    column_vector=cumsum2vector(cumsum_lrs_num);
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
total_pop = zeros(length(unique_zone_list),1);
for i=1:length(unique_zone_list)
    total_pop(i)=sum([TV0_data_building([TV0_data_building(:).zoneID].'==unique_zone_list(i)).residents]);
end
[val,idx]= sort(total_pop,'descend'); % val represents the population number
sorted_zone_list = unique_zone_list(idx);


% Let's assign schools into buildings layer
School_buildings_info = total_specialfac_buildings{1};
bld_id = size(TV0_data_building,1);
bld_id2 = max([TV0_data_building(:).bldID]);
zone_list_id = 0;
for i = 1 : numb_school
    zone_list_id = zone_list_id+1;
    if val(zone_list_id)==0 % If there are no population, go back to max population
        zone_list_id =1;
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
    if val(zone_list_id)==0 % If there are no population, go back to max population
        zone_list_id =1;
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
% Assumption :
% Only 20-65 years old individuals can work (AP5-AP9)

% Employment probability wrt gender by considering only individuals in
% labor force
%               EA1   EA2   EA3   EA4   EA5 
dist_table13 = [0.05, 0.05, 0.05, 0.10, 0.60; ... % Female
                0.05, 0.10, 0.15, 0.20, 0.75];    % Male

% Labor Force
dist_table12 = [0.86;... % Female
                0.89];   % Male

% Find out indices of individuals that can work (AP5-AP9)
individuals_indx_work = and([TV0_data_individual(:).age].' >4, [TV0_data_individual(:).age].' <10); % (AP5-AP9)
individuals_indx_work_male = and([TV0_data_individual(:).gender].' ==2 , individuals_indx_work);   % Male
individuals_indx_work_female = and([TV0_data_individual(:).gender].' ==1 , individuals_indx_work); % Female
total_female_work_numb = sum(individuals_indx_work_female);
total_male_work_numb = sum(individuals_indx_work_male);

[TV0_data_individual(:).Work] = deal(-1); % Assign all -1
[TV0_data_individual(individuals_indx_work).Work] = deal(1); % Assign only working group 1

female_assign_work = num2cell(rand(total_female_work_numb,1)<dist_table12(1)) ; % Only 0.86% can work, others unemployed
male_assign_work   = num2cell(rand(total_male_work_numb,1)<dist_table12(2));    % Only 0.89% can work, others unemployed
[TV0_data_individual(individuals_indx_work_female).Work] = deal(female_assign_work{:}); % wrt Labor Force
[TV0_data_individual(individuals_indx_work_male).Work] = deal(male_assign_work{:});     % wrt Labor Force

% Check individuals Education Attainment Status, and assign work 1 or
% unemployed (0) to individuals that have work property 1 which is
% calculated above.

for i= 1: size(dist_table13,2) % For all different education attainment status (for now 5)
    for k = 1:size(dist_table13,1) % For all genders
        individuals_indx_work_new = [TV0_data_individual(:).Work] == 1; % All employed
        individuals_indx_general = all([individuals_indx_work_new, [TV0_data_individual(:).gender] ==k,[TV0_data_individual(:).eduAttStat]==i] );
        total_numb = sum(individuals_indx_general);
        if total_numb==0
            continue;
        end
        assign_work = num2cell(rand(total_numb,1)<dist_table13(k,i)) ;
        [TV0_data_individual(individuals_indx_general).work] = deal(assign_work{:});
    end
end




% -------------------------------------------------------------------------
% STEP22 Assign IndividualFacID
% -------------------------------------------------------------------------
% Assumption : 
% Each individual is working within the total study area extent.
% Each individual (within schooling age limits) goes to school within the total study area extent.
working_places = {'Ind','Com','ResCom'};
working_place_indices = any([strcmp({TV0_data_building(:).OccBld}.','Ind') , strcmp({TV0_data_building(:).OccBld}.','Com') , strcmp({TV0_data_building(:).OccBld}.','ResCom')],2);
building_ids_workplaces = [TV0_data_building(working_place_indices).bldID].';


working_individuals_indices = [TV0_data_individual(:).Work]==1 ; % Working Individuals
total_working_indiv_numb = sum(working_individuals_indices);

assigned_building_ids = building_ids_workplaces(round(1+ (length(building_ids_workplaces)-1)*rand(total_working_indiv_numb,1))) ; % a+(b-a)*rand --> random between [a-b]
temp_building_id=num2cell(assigned_building_ids);
[TV0_data_individual(working_individuals_indices).Work] = deal(temp_building_id{:});


school_place_indices = [TV0_data_building(:).specialFac]==1 ; % School indices
school_building_id = [TV0_data_building(school_place_indices).bldID].'; % Building id of schools
school_individuals_indices = [TV0_data_individual(:).schoolEnrollment]==1 ; % Individuals going to school
total_student_numb = sum(school_individuals_indices);

assigned_building_ids = school_building_id(round(1+ (length(school_building_id)-1)*rand(total_student_numb,1))) ; % a+(b-a)*rand --> random between [a-b]
temp_school_bldid=num2cell(assigned_building_ids);
[TV0_data_individual(school_individuals_indices).schoolEnrollment] = deal(temp_school_bldid{:});

% Sum up all information for indivFacID
TV0_data_individual(1).indivFacID = [];
for i=1:size(TV0_data_individual,1)

%     TV0_data_individual(i).indivFacID = [num2str(TV0_data_individual(i).schoolEnrollment) ',' num2str(TV0_data_individual(i).Work)] ; %
    TV0_data_individual(i).indivFacID = [TV0_data_individual(i).schoolEnrollment , TV0_data_individual(i).Work] ;
end



% -------------------------------------------------------------------------
% STEP23 CommFacID
% -------------------------------------------------------------------------

% Random assignment (Identify closest facility for each individual in the next version)

TV0_data_household(1).CommFacID = []; % Initialize
hospital_place_indices = [TV0_data_building(:).specialFac]==2 ; % Hospital indices
hospital_building_id = [TV0_data_building(hospital_place_indices).bldID].'; % Building id of hospitals


assigned_building_ids = hospital_building_id(round(1+ (length(hospital_building_id)-1)*rand(size(TV0_data_household,1),1))) ; % a+(b-a)*rand --> random between [a-b]
temp_hospital_bldid=num2cell(assigned_building_ids);
[TV0_data_household(:).CommFacID] = deal(temp_hospital_bldid{:});
    

% -------------------------------------------------------------------------
% STEP24 Assign repValue
% -------------------------------------------------------------------------
% Assumption :
% Unit price for replacement wrt occupation type and special facility status of the building

Unit_price = [100; %Res
              150; %Com
              140; %Ind
              170; %ResCom
              95 ; %Edu
              135];%Hea
occupation_types = {'Res','Com','Ind','ResCom','Edu','Hea'};
TV0_data_building(1).repValue =[];
for i=1:length(Unit_price)
    multiplier = Unit_price(i);
    buildings_indx = strcmp({TV0_data_building(:).OccBld}.',occupation_types{i});
    temp_data = num2cell(([TV0_data_building(buildings_indx).fptarea].'.*[TV0_data_building(buildings_indx).nstoreys].') * multiplier);
    [TV0_data_building(buildings_indx).repValue] = deal(temp_data{:});

end


%--------------------------------------------------------------------------
% Finished Save Building/Household/Individual Layers
%--------------------------------------------------------------------------

% Clear out some data . (Keep fpt area for buildings for now)
TV0_data_building = rmfield(TV0_data_building, {'lut_number','OccBld','lrstype','CodeLevel','assigned','nstoreys'});
TV0_data_household = rmfield(TV0_data_household,{'income_numb','zoneType','zoneID'});
TV0_data_individual = rmfield(TV0_data_individual,{'schoolEnrollment','Work'});

%Force struct to table format
building_data  = struct2table(TV0_data_building);
household_data = struct2table(TV0_data_household);
individual_data = struct2table(TV0_data_individual);

% Save layers into excel file
writetable(building_data,[input_file_folder,'Building_Layer.xlsx']);
writetable(household_data,[input_file_folder,'Household_Layer.xlsx']);
writetable(individual_data,[input_file_folder,'Individual_Layer.xlsx']);
writetable(TV0_data_landuse,[input_file_folder,'Landuse_Layer.xlsx']);






%--------------------------------------------------------------------------
% Functions Used
%--------------------------------------------------------------------------

function building = generate_new_building(lut_number,LRS_Table,nStoreys_Table, fpt_prob)
    pd_lrs = makedist('Multinomial','Probabilities',LRS_Table{lut_number});  % LRS Probability distribution
    lrs_val=random(pd_lrs,1,1); % LRS
    pd_nstoreys = makedist('Multinomial','Probabilities',nStoreys_Table{lut_number,lrs_val}); % Number of Storeys distribution
    nstoreys_profile_val=random(pd_nstoreys,1,1); % number of storeys (1-LR 2-MR 3-HR)
    if nstoreys_profile_val==1 % LR
        nstoreys = round(1 + 3*rand(1,1));
    elseif nstoreys_profile_val==2 % MR
        nstoreys = round(5 + 3*rand(1,1));
    elseif nstoreys_profile_val==3 % HR
        nstoreys = round(9 + 10*rand(1,1));
    end
    fptBLD = round(fpt_prob(1) + (fpt_prob(2)-fpt_prob(1)).*rand(1,1));
    building=[ lrs_val, nstoreys , fptBLD];     
end



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








