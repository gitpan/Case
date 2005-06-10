#!perl
use strict;
use warnings;

use Test::More tests =>
20;

BEGIN { use_ok 'Case'; }

my $case = dispatcher(
  'foo' => sub {5}
);

ok($case, 'create switch');
is($case->('foo'), 5, 'found');
is($case->('bar'), undef, 'default default');

$case->(
  Case::default => sub { 'my default' }
);

is($case->('baz'), 'my default', 'added default');

$case->(
  qw(foo bar baz) => sub {'fell thru'},
  Case::default   => sub {'too far'}
);

is($case->('foo'), 'fell thru', 'reassigned; normal fall-thru');
$case->(foo => undef);
is($case->('foo'), 'too far', 'removed case');
$case->(\&Case::default);
is($case->('foo'), undef, 'reset default');

$case = dispatcher(
  qw(foo bar) => sub {'one ' . Case::action('baz')},
  sorbet      => sub {'to cleanse the palate'},
  baz         => sub {'chain'}
);

is($case->('foo'), 'one chain', 'chaining');

$case = dispatcher(
  qw(foo bar)    => sub {"got $_"},
  baz            => sub {Case::action('foo')},
  roy            => sub { 'special '. Case::action('foo')},
  Case::default  => sub { 'Just wasting space' }
);

is($case->('foo'), 'got foo', 'arg is $_');
is($case->('baz'), 'got baz', 'arg is $_ when chained');
is($case->('roy'), 'special got roy', 'cat chained return');

$case->(foo => sub {"using $_[0]"});
is($case->('foo'), 'using foo', 'arg is $_[0], too');

# Weird constructions
ok(dispatcher(), 'completely empty');
ok(dispatcher(sub{}), 'default only');
ok(dispatcher('foo'), 'term, no sub');
diag("Should get a malformed dispatch table warning");
ok(dispatcher(sub{}, sub{}), 'malformed dispatch table warning');

# Note: using an arrayref here would cause dispatcher to
# successfully return an array_style dispatcher.
eval {
    dispatcher(
      \'aref' => sub { 'Cannot handle' }
    );
};
ok($@, "non-code ref as term dies");

eval {
    dispatcher(
      'what?' => ['aref']
    );
};
ok($@, "non-code ref as action dies");

eval {
    dispatcher(
      ['aref']
    );
};
ok($@, "non-code ref as default dies");

