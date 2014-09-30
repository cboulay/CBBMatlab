function cfn = class2Cfn(testY, predY)

uqClasses = unique(cat(1, testY, predY));
nClasses = length(uqClasses);
cfn = nan(nClasses);
for ct = 1:nClasses
    tc = uqClasses(ct);
    for cp = 1:nClasses
        pc = uqClasses(cp);
        cfn(ct, cp) = sum(predY(testY==tc)==pc);
    end
end