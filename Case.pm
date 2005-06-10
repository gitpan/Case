package Case;

use strict;
use warnings;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
use Carp;

require Exporter;

@ISA = qw(Exporter);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(dispatcher);
@EXPORT_OK=qw(default is_number);
$VERSION = '0.0.1';

# Preloaded methods go here.

sub default {}

# If there is an arrayref in the mix, call hash_style
# otherwise, call array_style
sub dispatcher {
    for (@_) { return &array_style if ref eq 'ARRAY' }
    &hash_style;
}

sub hash_style {
    my %swash;
    my $default = \&default;
    my $code;
    my $assigned_code;
    # Handle degenerate case
    return $default if (@_ == 0);
    # Handle default
    if ((ref $_[-1]) eq 'CODE' and (@_ ==1 or ref $_[-2] eq 'CODE')) {
	$default = pop(@_);
    }
    
    for my $item (reverse @_) {
        if ((my $reftype = ref $item) eq 'CODE') {
            carp "Malformed dispatch table: action with no terms"
	      if $code and ! $assigned_code;
	    $code = $item;
	    $assigned_code = 0;
        }
        elsif ($reftype) {
            croak "dispatch table cannot handle $reftype-ref arguments";
        }
        else {
            $swash{$item} = $code;
            ++$assigned_code;
        }
    }
    carp "Malformed dispatch table: action with no terms"
      if $code and ! $assigned_code;
    return sub {
        if (@_ > 1 or ref($_[0]) eq 'CODE') {
	    reassign(\%swash, \$default, @_);
	}
        else {
            local($_) = @_;
            local *Case::action = sub { ($swash{$_[0]} || $default)->($_) };
            &Case::action;
        }
    };
}

sub reassign {
    my $swashref = shift;
    my $defaultref = shift;
    my $code;
    my $assigned_code;
    # Handle default
    if (@_ ==1 or ref $_[-2] eq 'CODE') {
        if (ref $_[-1] eq 'CODE') { $$defaultref = pop(@_) }
        else { croak "inappropriate type for default: $_[-1]" }
    }
    for my $item (reverse @_) {
        if (!defined($item) or (my $reftype = ref $item) eq 'CODE') {
            carp "Malformed dispatch table: action with no terms"
	      if $code and ! $assigned_code;
	    $code = $item;
	    $assigned_code = 0;
        }
        elsif ($reftype) {
            croak "dispatch table cannot handle $reftype-ref ($item) arguments";
        }
        else {
            defined($code)
            ? $swashref->{$item} = $code
            : delete $swashref->{$item};
            ++$assigned_code;
        }
    }
    carp "Malformed dispatch table: action with no terms"
      if $code and ! $assigned_code;
}

sub is_number { @_ and ($_[0] & ~$_[0]) eq '0' }

sub in_range {
    @_ == 2 or croak "Incorrect number of arguments (@_) to in_range";
    my ($lo, $hi) = @_;
    my ($number_range) = is_number($lo);
    if ($number_range != is_number($hi)) {
	croak "Endpoints of range are mismatched numeric and string"
    }
    # Only match ranges of the same type as the topic
    elsif ($number_range != is_number($_)) { return 0 }
    elsif ($number_range) {
        if ($lo > $hi) {
	    carp "Backward range $lo .. $hi" if warnings::enabled('numeric');
	    ($lo, $hi) = ($hi, $lo);
	}
	return ($lo <= $_ and $_ <= $hi);
    }
    elsif ($lo gt $hi) {
	carp "Backward range $lo .. $hi" if warnings::enabled('numeric');
	($lo, $hi) = ($hi, $lo);
    }
    return ($lo le $_ and $_ le $hi);
}


# This one does the comparisons
# Resume is a recursive call with a starting point
sub process_smatch {
    my ($tags, $testlist, $start_at) = @_;
    for my $casenum ($start_at .. $#$testlist) {
        my ($testset, $execute_sub) = @{$testlist->[$casenum]};
        for my $case (@$testset) {
            my $testtype = ref $case;
           if (($testtype eq '')
               and do {
                   if (is_number($case)) {
                       is_number($_) and $case == $_;
                   }
                   else {
                       !is_number($_) and $case eq $_;
                   }
               }
              or ($testtype eq 'Regexp' and m{$case})
              or ($testtype eq 'ARRAY'  and in_range(@$case))
              or ($testtype eq 'HASH'   and exists $case->{$_})
              or ($testtype eq 'CODE'   and $case->($_))
               ) {
                no warnings 'redefine';
                local *Case::action = sub {
                    $testlist->[$tags->{$_[0]}][1]->($_);
                };
                local *Case::resume = sub {
                    process_smatch($tags, $testlist,
                                   @_ ? $tags->{$_[0]} : $casenum + 1
                                  );
                };
                return $execute_sub->($_);
            }
        }
    }
}

# This one verifies the structure 
sub array_style {
    my $default = \&Case::default;
    my %tags;
    my ($tag, $testset);
    my $item;
    my @testlist = ();

    if (ref $_[-1] ne 'CODE') {
        croak "Trailing junk after last coderef";
    }
    if (@_ == 1 or ref $_[-2] eq 'CODE') {
        $default = pop @_;
    }

    # First, find all the tags and verify correct structure
    for my $i (0..$#_) {
        $item = $_[$i];
        my $reftype = ref $item;
        if ($reftype eq '') {
            $tags{$item} = @testlist; # indicates next test/action pair
            if ($testset) {
                croak "tag appears after testset";
            }
            elsif ($tag) {
                carp "$item duplicates $tag";
            }
            $tag = 1;
        }
        elsif ($reftype eq 'ARRAY') {
            if ($testset) {
                croak "multiple testsets with no action";
            }
            $testset = $item;
        }
        elsif ($reftype eq 'CODE') {
            push @testlist, [$testset, $item];
            $testset = $tag = undef;
        }
        else {
            croak "($item) does not belong here";
        }
    }
    push @testlist, [ [sub {'a'}], $default ];
    sub {
        local *_ = \$_[0];
        process_smatch(\%tags, \@testlist, 0)
    };
}

1;
__END__
=head1 NAME

Case - lightweight, pure-Perl, multiway decision constructs

=head1 VERSION

This document describes version 1.00 of Case,
released June, 2005.

=head1 SYNOPSIS

    use Case;
    my $case = dispatcher(
      'mozart'            => sub { "$_ was a Musician!\n"
                                   . Case::action('einstein');
                                 },
      qw(dog cat pig)     => sub { "$_ is an Animal!\n"; },
      qw(einstein newton) => sub { "$_ was a Genius!\n"; },
      'Roy'               => sub { "$_ should fall through..."
                                   . Case::action(Case::default);
                                 },
      Case::default       => sub { "No idea what $_ is.\n" }
    );
    print $case->('mozart');

or

    use Case;
    my $case = dispatcher
        [ qw(dog cat) ]  => sub { print '$_ is an animal';
                                  Case::action(Case::default)
                                },
        [ [1,10] ]       => sub { print 'number in range';
                                  Case::resume('special')
                                },
      special =>
        [ @array, 42 ]   => sub { print 'number in list' },
        [ qr/\w+/    ]   => sub { print 'pattern match' },
        [ \%hash     ]   => sub { print 'entry exists in hash' },
        [ \&sub      ]   => sub { print 'sub returns true value' },
        Case::default    => sub { print 'default' }
    ;
    $case->($val);

=head1 DESCRIPTION

The Case module provides two ways to determine which of a set of
alternatives a given scalar matches, and take the appropriate action.
One is more flexible about what types of matches can be done, the
other is more efficient at finding an exact string match.

=head2 Setting up the test table

C<dispatcher> examines the argument list to see which flavor of
dispatcher you are creating. For exact string matching (only),
the arguments should be strings interspersed with coderefs, as
in the first example above. For smart-matching, the arguments
should be of the form optional-tag/arrayref-of-tests/coderef.

In both cases, the default is preceded by no test (or the
equivalent call to C<Case::default>).

=head2 Executing a test

In either case, the return value is a coderef. Pass a value to that
coderef to execute the code associated with (a test that matches)
that value.

=head2 Modifying the dispatch table

The string-matching dispatcher allows you to modify the table
by passing more than one argument to the dispatcher you have
created. You can define new entries using the same syntax as
when originally defining it, and you can delete entries by
passing C<undef> as the action coderef associated with the terms
you want deleted. Passing a single coderef will redefine the
default action.

You cannot adjust the smart-matching dispatcher after it has been
created.

=head2 FALLTHROUGH, CHAINING, and RESUME

In C's C<switch> statement, fallthrough exists for you to be able to
stack terms up. You get that behavior automatically here by preceding
a coderef with all the terms that map to it. Fallthrough from one
coderef to the next is discouraged in C, and does not happen in this
implementation, per se.

Within the action coderefs, you can call the coderef associated with
another term or test by calling the magically-defined C<Case::action( )>
with the term (in the case of string-matching flavor), or the tag
(in the case of smart-matching flavor) of the test. This is
a safer and more flexible way to chain actions together than C-style
fallthrough. To call the default case, you can pass no
arguments, or (equivalently, but self-documenting), C<Case::default( )>
as the argument.

If you wish to resume testing in the smart-matching flavor, call
C<Case::resume(tag)>. Calling resume with no argument will cause it
to fall through to the next test (which need not have a tag).

B<Note:> The chaining calls are subroutine calls, and will return
to the caller just like any subroutine. If the chaining call is not
the last statement in your action, you should probably make it part
of a C<return> statement.

=head2 SMART-MATCHING RULES

A match is found when an element of the arrayref, evaluated
according to this table, yields a true value:

 Element ($test)    Example         Operation
 ================   =============   =====================================

 Regex              qr/foo|bar/     /$test/

 Number             3.14            $_ == $test

 coderef            sub { /foo/ }   $test->($_)

 number range       [100,1000]      $test->[0] <= $_ and $_ <= $test->[1]

 text range         ['a', 'arf']    $test->[0] le $_ and $_ le $test->[1]

 hashref            \%hash          exists $test->{$_}

 any other scalar   'a string'      $_ eq $test

=head2 Ranges

An arrayref is interpreted as a range of either numbers or strings.
The test will pass if the value being checked is between the two range
endpoints (inclusive).

The endpoints can appear in either order, but it is an error to have
one numeric and one non-numeric, a ref, or not exactly two values in
the range specifier.

To smart-match against all elements of an array, you can include a
ref to the array as a testset (don't wrap it in [] ). To combine it
with other tests, make the action C<sub {Case::resume()}> and put the
rest of the tests as the next testset.

=head2 Coderef Tests

Coderef tests are your fallback option. If the test you want to
perform is not one of the provided variety, write it yourself and
plug it in.

Coderefs (both tests and actions) are called with the value being
tested aliased to both C<$_> and (the first element of) C<@_>. That
is so you can compactly do things like C<sub {s/foo/bar}> and also
C<sub {grep /$_[0]/, @foo}>.

=head2 Standard Exports

The Case module exports C<dispatcher> by default

=head2 Optional Exports

The following routines will be exported into your namespace
if you specifically ask that they be imported:

C<default> is a completely empty subroutine, useful as a tag to
label the default case (you don't need to import it;
 C<< Case::default => \&whatever >> looks fine, but you may
import it if you want).

C<is_number> is a helper function for distinguishing between numbers
and strings.

=head1 NOTES

When smart-matching ordinary scalars, if both are determined to be numbers,
then numeric comparison is done; otherwise, string comparison is
done. Stringify or numify as necessary to get the comparison you want.

This is not an object-oriented module. Nothing is C<bless>ed into the
Case package.

=head1 AUTHOR

Roy Johnson

