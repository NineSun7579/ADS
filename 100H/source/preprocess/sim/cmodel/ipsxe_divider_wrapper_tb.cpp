#include "ipsxe_divider_def_v1_0.h"
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>

// Declare external variables
int op_sel;
int dividend;
int divisor;
int dividend_width;
int divisor_width;
bool is_signed;
int udividend;
int udivisor;
int udividend_width;
int udivisor_width;
int fractional_width;
bool is_signed_u;
bool fractional;

int main() {
    // Configure and test the lutmult operation
    op_sel = 2;
    dividend = 4578;
    divisor = 87;
    dividend_width = 17;
    divisor_width = 12;
    is_signed = true;
    udividend = 0;
    udivisor = 0;
    udividend_width = 0;
    udivisor_width = 0;
    fractional_width = 0;
    is_signed_u = false;
    fractional = false;

    switch (op_sel) {
    	case 2:
    		testDivider(op_sel,dividend,divisor,dividend_width,divisor_width,is_signed,udividend,udivisor,udividend_width,udivisor_width,fractional_width,is_signed_u,fractional);
    		break;
    	case 1:
    		testDivider(op_sel,dividend,divisor,dividend_width,divisor_width,is_signed,udividend,udivisor,udividend_width,udivisor_width,fractional_width,is_signed_u,fractional);
    		break;
    	case 0:
    		testDivider(op_sel,dividend,divisor,dividend_width,divisor_width,is_signed,udividend,udivisor,udividend_width,udivisor_width,fractional_width,is_signed_u,fractional);
    		break;
    }
    return 0;
}