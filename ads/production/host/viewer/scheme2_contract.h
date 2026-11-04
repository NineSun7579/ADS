#pragma once
#include "rknn_api.h"
#include "fpga_infer_input.h"
namespace scheme2 {
inline bool sameTensor(const rknn_tensor_attr& a, const rknn_tensor_attr& b) {
    if (a.index != b.index || a.n_dims != b.n_dims || a.n_elems != b.n_elems ||
        a.size != b.size || a.fmt != b.fmt || a.type != b.type || a.qnt_type != b.qnt_type ||
        a.zp != b.zp || a.scale != b.scale || a.fl != b.fl ||
        a.w_stride != b.w_stride || a.h_stride != b.h_stride || a.size_with_stride != b.size_with_stride) return false;
    for (uint32_t i = 0; i < a.n_dims; ++i) if (a.dims[i] != b.dims[i]) return false;
    return true;
}
inline bool packedInput(const rknn_tensor_attr& a, int height) {
    return (height == 480 || height == 640) && a.index == 0 && a.n_dims == 4 && a.dims[0] == 1 && a.dims[1] == uint32_t(height) &&
        a.dims[2] == 640 && a.dims[3] == 3 && a.fmt == RKNN_TENSOR_NHWC &&
        (a.type == RKNN_TENSOR_UINT8 || a.type == RKNN_TENSOR_INT8) &&
        a.size == bytes(height) && a.n_elems == bytes(height) &&
        (!a.w_stride || a.w_stride == 640) && (!a.h_stride || a.h_stride == uint32_t(height)) &&
        (!a.size_with_stride || a.size_with_stride == bytes(height));
}
inline rknn_tensor_attr userInput(rknn_tensor_attr native) {
    // Runtime converts unsigned RGB user bytes to the model's native dtype.
    // Native attrs remain independently queried/compared; no signed CPU cast.
    native.type = RKNN_TENSOR_UINT8;
    native.fmt = RKNN_TENSOR_NHWC;
    native.pass_through = 0;
    return native;
}
}
