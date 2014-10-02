function result = dimfun(m, func, varargin)
if isempty(varargin)
    mydim = min(2,ndims(m));
else
    mydim = min(varargin{1},ndims(m));
    if length(varargin)>1
        myargs = varargin{2:end};
    else
        myargs = [];
    end
end

result = m;
if mydim == 1
    for d_ix= 1:size(m,mydim)
        result(d_ix,:)= func(m(d_ix,:), myargs(:));
    end
elseif mydim == 2
    for d_ix= 1:size(m,mydim)
        result(:,d_ix)= func(m(:,d_ix), myargs(:));
    end
elseif mydim == 3
    for d_ix= 1:size(m,mydim)
        result(:,:,d_ix)= func(m(:,:,d_ix), myargs(:));
    end
end

end