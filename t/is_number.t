use strict;
use warnings;

use Test::More tests =>
8;

BEGIN { use_ok 'Case', 'is_number' }

#
# Test is_number

ok(is_number(5), '5 is a number');
ok(!is_number('pig'), 'pig is not a number');
ok(is_number(3.14159), '3.14159 is a number');
ok(!is_number('5'), '"5" is not a number');
ok(is_number(0), '0 is a number');
ok(!is_number('0'), '"0" is not a number');
ok(!is_number(), '<no args> is not a number');