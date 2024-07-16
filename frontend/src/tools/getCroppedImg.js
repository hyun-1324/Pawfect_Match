async function getCroppedImg(imageSrc, crop, zoom) {
    // Create an image element
    const image = new Image();
    image.src = imageSrc;
    await new Promise((resolve) => {
        image.onload = resolve;
    });

    // Create a canvas with the final dimensions of the cropped area
    const canvas = document.createElement('canvas');
    const scaleX = image.naturalWidth / image.width;
    const scaleY = image.naturalHeight / image.height;
    canvas.width = crop.width;
    canvas.height = crop.height;
    const ctx = canvas.getContext('2d');

    // Draw the cropped image on the canvas
    ctx.drawImage(
        image,
        crop.x * scaleX,
        crop.y * scaleY,
        crop.width * scaleX * zoom,
        crop.height * scaleY * zoom,
        0,
        0,
        crop.width,
        crop.height
    );

    // Convert the canvas to a Blob
    return new Promise((resolve, reject) => {
        canvas.toBlob((blob) => {
            if (!blob) {
                // Reject the Promise if the blob couldn't be created
                reject(new Error('Canvas is empty'));
                return;
            }
            resolve(blob);
        }, 'image/png');
    });
}

export default getCroppedImg;