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