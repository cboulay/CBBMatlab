function testBool = cvDistrib(classVec, ncv)
%function testBool = cvDistrib(classVec, ncv)
%

nTrials = length(classVec);
uqY = unique(classVec);
randTID = randperm(nTrials);
randY = classVec(randTID);
testBool = false(nTrials, ncv);

for cl_ix = 1:length(uqY)
    cl_id = uqY(cl_ix);
    cl_tr_id = randTID(randY == cl_id);
    edges = 0:length(cl_tr_id)/ncv:length(cl_tr_id);
    temp_id = 1:length(cl_tr_id);
    for cv_ix = 1:ncv
        test_id = cl_tr_id(temp_id > edges(cv_ix) & temp_id <= edges(cv_ix + 1));
        testBool(test_id, cv_ix) = true;
    end
end