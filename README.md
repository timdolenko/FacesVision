# FacesVision

Demo app for gender classification of facial images using `GenderNet`, `Vision` and `CoreML`.

<div align="center">
<img src="https://github.com/tymofiidolenko/FacesVision/blob/master/sample.gif" alt="FacesVisionDemo" width="600" height="338" />
</div>

## Installation

Run the app on the device with iOS 12 and higher.

## How it works
```capture photo
detect faces with Vision
for each face
  crop photo to face rect
  classify cropped photo with GenderNet
  display overlay
```

## Gender classification model

This app is based on the gender neural network classifier,
which was converted from `Caffe` model to `CoreML` model using [coremltools](https://pypi.python.org/pypi/coremltools) python package.

Ready to use CoreML model is stored in this repository. If you want you can find original Caffe model [here](http://www.openu.ac.il/home/hassner/projects/cnn_agegender/) and convert it to CoreML yourself.

## Requirements

- Xcode 10
- iOS 12

## References
- [Age and Gender Classification using Convolutional Neural Networks](https://talhassner.github.io/home/publication/2015_CVPR/)
- [Faces Vision Demo](https://github.com/cocoa-ai/FacesVisionDemo)
- [Caffe Model Zoo](https://github.com/caffe2/caffe2/wiki/Model-Zoo)
- [Apple Machine Learning](https://developer.apple.com/machine-learning/)
- [Vision Framework](https://developer.apple.com/documentation/vision)
- [CoreML Framework](https://developer.apple.com/documentation/coreml)
- [coremltools](https://pypi.python.org/pypi/coremltools)
