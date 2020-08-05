sheep = imread('datasets/Multi_Focus_example/sheep.jpeg');
gray_sheep = rgb2gray(sheep);
mask = zeros(size(gray_sheep));
mask(30:end-32,50:end-40) = 1;

bw = activecontour(gray_sheep, mask, 300);

se = strel('disk', 3, 0);
o = imopen(bw, se);

w = fspecial('gaussian', [16 16], 4);
blurred_sheep = imfilter(sheep, w);

[row, col] = size(bw);
foreground_inFocus_sheep = sheep;
background_inFocus_sheep = sheep;

for i=1:row
    for j=1:col
        for d=1:3
            if bw(i,j) == 0
                foreground_inFocus_sheep(i,j,d) = blurred_sheep(i,j,d);
            end
        end
    end
end

for i=1:row
    for j=1:col
        for d=1:3
            if bw(i,j) == 1
                background_inFocus_sheep(i,j,d) = blurred_sheep(i,j,d);
            end
        end
    end
end

figure;
subplot(1,3,1); imshow(sheep);
subplot(1,3,2); imshow(uint8(foreground_inFocus_sheep));
subplot(1,3,3); imshow(uint8(background_inFocus_sheep));

imwrite(foreground_inFocus_sheep, 'datasets/Multi_Focus_example/foreground_inFocus_sheep.jpg');
imwrite(background_inFocus_sheep, 'datasets/Multi_Focus_example/background_inFocus_sheep.jpg');
