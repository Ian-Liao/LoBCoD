sheep = imread('datasets/Multi_Focus_example/sheep.jpeg');
gray_sheep = rgb2gray(sheep);
mask = zeros(size(gray_sheep));
mask(30:end-32,50:end-40) = 1;

% Segment image into foreground and background using active contour.
bw = activecontour(gray_sheep, mask, 300);

% Create morphological structuring element.
se = strel('disk', 3, 0);
bw2 = imopen(bw, se);

% Remove small objects from binary image
bw3 = bwareaopen(bw2, 80);

figure;
subplot(2,2,1); imshow(mask); title('Initial Mask');
subplot(2,2,2); imshow(bw); title('Raw Segment Result');
subplot(2,2,3); imshow(bw2); title('Opening Result');
subplot(2,2,4); imshow(bw3); title('Area Opening Result');

w = fspecial('gaussian', [16 16], 4);
blurred_sheep = imfilter(sheep, w);

[row, col] = size(bw);
foreground_inFocus_sheep = sheep;
background_inFocus_sheep = sheep;

for i=1:row
    for j=1:col
        for d=1:3
            if bw3(i,j) == 0
                foreground_inFocus_sheep(i,j,d) = blurred_sheep(i,j,d);
            else
                background_inFocus_sheep(i,j,d) = blurred_sheep(i,j,d);
            end
        end
    end
end

figure;
subplot(2,2,1); imshow(sheep); title('Original image');
subplot(2,2,2); imshow(blurred_sheep); title('Blurred image');
subplot(2,2,3); imshow(uint8(foreground_inFocus_sheep)); title('Foreground in-focus');
subplot(2,2,4); imshow(uint8(background_inFocus_sheep)); title('Background in-focus');

imwrite(foreground_inFocus_sheep, 'datasets/Multi_Focus_example/foreground_inFocus_sheep.jpg');
imwrite(background_inFocus_sheep, 'datasets/Multi_Focus_example/background_inFocus_sheep.jpg');
