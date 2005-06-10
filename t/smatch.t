use strict;
use warnings;

use Test::More tests =>
18;

BEGIN { use_ok 'Case' }

#
# Test smatch

my $smatch = dispatcher( [qw(dog cat)] => sub {'animal'} );
is($smatch->('dog'),
   'animal',
   'simple lookup'  );

is($smatch->('sheep'),
   undef,
   'default default'  );

$smatch = dispatcher([qw(dog cat)] => sub {'animal'},
                     [ '3' ]       => sub {'string match'},
                     [ 03 ]        => sub {'numbers match'},
                     [qr/g$/]      => sub {'regex match'},
                     Case::default => sub {'something else'}
                    );
is($smatch->('sheep'),
   'something else',
   'supplied default');

is($smatch->('reg'),
   'regex match',
   'regex match'  );

is($smatch->(3),
   'numbers match',
   'numbers skip strings to match numbers');

$smatch = dispatcher([ '03' ] => sub {'matched string'}, sub {'mismatch'});

is($smatch->(3),
   'mismatch',
   'numeric vs non-numeric forces string compare');


$smatch = dispatcher([ [1,10] ]    => sub {'range match'},
                     Case::default => sub { 'mismatch' });

is($smatch->(3.1),
   'range match',
   'number range match');

is($smatch->('5'),
   'mismatch',
   'text does not match numeric range');

$smatch = dispatcher([ ['3some','5 little indians'] ] => sub {'range match'},
                     Case::default                    => sub { 'mismatch' });

is($smatch->(4),
   'mismatch',
   'number does not match text range');

is(dispatcher([ '1' ]        => sub {'first'},
              [ ['1','10'] ] => sub {'second'},
              sub {'and default'})->('1'),
   'first',
   'aborts after first match');
            

is(dispatcher(target => ['foo'] => sub {"bullseye on $_"},
              [ '1' ] => sub { 'hit' . Case::action('target') },
              [ [1,10] ] => sub {'decoy'})->('1'),
   'hitbullseye on 1',
   'tag, match, chain, substitute');

diag("Mismatched range ends should die");
eval {
    dispatcher([['1',10]] => sub {"should die"})->('1');
};
ok($@, "Mismatched range ends got '$@'");

my $foo = 'perl';
dispatcher([qr/p/] => sub {s/per/came/})->($foo);
is($foo, 'camel', 'subs can edit topic');


$smatch = dispatcher(['one'] => sub { 'first'.Case::resume('there') },
                     [qr/o/] => sub { 'matches, but should be skipped' },
                     there => [qr/n/] => sub { ' and last' },
                     ()      => sub { 'default' });
is($smatch->('one'),
   'first and last',
   'resume skips');

$smatch = dispatcher(['one'] => sub { 'first'.Case::resume() },
                     [qr/o/] => sub { ' resumed' },
                     there => [qr/n/] => sub { ' and last' },
                     ()      => sub { 'default' });
is($smatch->('one'),
   'first resumed',
   'resume w/o args falls through');

$smatch = dispatcher(['one'] => sub { Case::resume() },
                     [{crap => undef}] => sub {'crap exists'},
                     [qr/o/] => sub { 'resumed and matched' },
                   there => [qr/n/] => sub { ' and last' },
                     ()      => sub { 'default' });
is($smatch->('one'),
   'resumed and matched',
   'resumed and matched');

is($smatch->('crap'),
   'crap exists',
   'hash existence');
