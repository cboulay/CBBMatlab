function predY = classifyNaiveBayesMulti(trainX, trainY, testX, varargin)
% Naive Bayes using multiple models.
%function [cfnOut, classVec] = classifyNaiveBayesMulti(trainX, trainY, testX, testY, 'param', value)
%Valid parameters include {'model'}
%Or the first additional argument can be a structure containing one or more
%fields with these names.
%model is the type of distribution used to model the priors. It can be a
%single string 'poiss', 'norm', or 'logn' to use that model for all x in X,
%or it can be a cell array of strings - one for each x

%% Parameters
[nTrainTrials, nFeatures] = size(trainX);
params.model = repmat({'poiss'}, 1, nFeatures); %'norm' 'logn'
params = varg2params(varargin, params, {'model'});
if ~iscell(params.model)
    params.model = repmat({params.model}, 1, nFeatures);
end

%% Prepare X and Y (Cj)
% Remap classes onto integers 1:nClasses
uqClass = unique(trainY);
nClasses = length(uqClass);

% Remove features that are constant in training data.
badFtBool = sum(diff(trainX) == 0) == (nTrainTrials - 1);
trainX = trainX(:, ~badFtBool);
testX = testX(:, ~badFtBool);
params.model = params.model(~badFtBool);
[~, nFeatures] = size(trainX);

%% Train the model.

%Class probabilities:
classCount = hist(trainY, uqClass);
priorY = classCount ./ length(trainY);

%Model parameters
%(Note: Conditional X priors are calculated during testing)
model_params = nan(nFeatures, nClasses, 2); %2 for 'norm' or 'logn', only 1 needed for 'poiss'
uqmod = unique(params.model);
for mt = 1:length(uqmod) %For each type of model
    
    %Identify the features that use this model
    modBool = strcmpi(params.model, uqmod{mt});

    if strcmpi(uqmod{mt}, 'poiss')
        
        %Poisson has one parameter: Lambda, equal to the mean == std
        for cc = 1:nClasses
            model_params(modBool, cc, 1) = mean(trainX(trainY == uqClass(cc), modBool));
        end
        model_params(modBool, :, 1) = model_params(modBool, :, 1) + 0.5;%Cannot be zero
        
    elseif any(strcmpi(uqmod{mt}, {'norm', 'logn'}))
        
        %Normal has mu and sigma
        for cc = 1:nClasses
            model_params(modBool, cc, 1) = mean(trainX(trainY==uqClass(cc), modBool));
            model_params(modBool, cc, 2) = std(trainX(trainY==uqClass(cc), modBool));
        end
        
    end 
end
clear mt modBool cc


%% Test the model.
nTest = size(testX, 1);
pYgX = nan(nTest, nClasses); %Probability of class Y given X
for cc = 1:nClasses
    for tx = 1:nTest
        %pYgX = P(Y)*P(X|Y) / P(X). Ignore the denominator because it
        %is the same for every class.

        %Multiplying the probabilities leads to tiny numbers:
        %prod(priorY(cc)) * prod( pdf(params.model, test_x(tx,:)', lambads(:,cc)))

        %Instead, sum the log of probabilities:
        sumlogp = log(priorY(cc));

        for mt = 1:length(uqmod) %For each type of model
            modBool = strcmpi(params.model, uqmod{mt});
            
            if strcmpi(uqmod{mt}, 'poiss')
                
                morelogp = sum(log( pdf(uqmod{mt}, testX(tx, modBool)', model_params(modBool, cc, 1)) ));
                sumlogp = sumlogp + morelogp;
                
            elseif any(strcmpi(uqmod{mt}, {'norm', 'logn'}))
                
                %It is possible that, for this class, some features were
                %constant and thus have a std of 0. Avoid those.
                modBool = modBool & model_params(:, cc, 2)' ~= 0;
                
                morelogp = sum(log(...
                    pdf(uqmod{mt}, testX(tx, modBool)', model_params(modBool, cc, 1), model_params(modBool, cc, 2)) ));
                
                sumlogp = sumlogp + morelogp;
                
            end 
        end
        pYgX(tx, cc) = sumlogp;
    end
end
[~, predY] = max(pYgX, [], 2);