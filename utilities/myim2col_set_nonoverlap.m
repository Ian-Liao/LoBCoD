function patches = myim2col_set_nonoverlap(im, n)

% the signal boundaries are padded with n-1 elements prior to decomposing
% it with the model
padded = padarray(im, [n-1,n-1], 'both');

cnt = 1;
patches = cell(1,n^2);
for dx = 1:n
    for dy = 1:n
        tmp = padded(dy:end,dx:end);
        % Extracts nonoverlap neighborhoods of tmp
        % with a step size of (n,n) between them
        patches{cnt} = im2colstep(tmp, [n,n], [n,n]);
        cnt = cnt + 1;
    end
end

return

