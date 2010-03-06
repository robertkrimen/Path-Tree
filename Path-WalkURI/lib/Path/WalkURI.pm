package Path::WalkURI;

use strict;
use warnings;

use Any::Moose;

use Path::WalkURI::SimpleWalker;

sub walk {
    my $self = shift;
    my $path = shift;

    return Path::WalkURI::SimpleWalker->new( path => $path );
}

sub normalize_path {
    my $self = shift;
    local $_ = shift;

# TODO Reintegrate this
#    $_ = "/$_";
#    s#/+#/#g;

    return $_;
}

sub consume {
    my $self = shift;
    my $step = shift;
    my $rule = shift;

    my $path = $step->leftover;

    return unless my $match = $rule->match( $path );

    my $leftover = $match->{leftover};
    my $segment = substr $path, 0, -1 * length $leftover;
    my $prefix = $step->prefix . $step->segment;

    return {
        captured => $match->{arguments},
        leftover => $leftover,
        segment => $segment,
        prefix => $prefix,
    };
}

sub parse_rule {
    my $self = shift;
    my $input = shift;

    # TODO Always match?
    if ( ref $input eq '' ) {
        return Path::WalkURI::Rule::SlashPattern->new( pattern => $input );
    }
    elsif ( ref $input eq 'Regexp' ) {
        return Path::WalkURI::Rule::Regexp->new( regexp => $input );
    }
    else {
        die "Do not know how to parse rule ($input)";
    }
}

package Path::WalkURI::Rule::Regexp;

use Any::Moose;

has regexp => qw/ is ro required 1 isa Regexp /;
has _regexp => qw/ is ro lazy_build 1 /;

sub _build__regexp {
    my $self = shift;
    my $regexp = $self->regexp;

    # TODO This is done because of issues with $'
    # Also because it seems to be the sane thing you would want to do
    # (Not match a branching action in the middle)
    # What about leading space, delimiter garbage, etc.?

    $regexp = qr/^$regexp/;
    return $regexp;
}

sub regexp_match {
    my $self = shift;
    my $path = shift;
    my $regexp = shift;

    return unless my @arguments = $path =~ $regexp;
    my $leftover_path = eval q{$'};

    undef @arguments unless defined $1; # Just got the success indicator

    return {
        leftover => $leftover_path,
        arguments => \@arguments,
    };
}

sub match {
    my $self = shift;
    my $path = shift;

    return $self->regexp_match( $path, $self->_regexp );
}

package Path::WalkURI::Rule::SlashPattern;

use Any::Moose;

has pattern => qw/ is ro required 1 isa Str/;
has regexp => qw/ is ro lazy_build 1 /;
sub _build_regexp {
    my $self = shift;
    return $self->parse( $self->pattern );
}

sub parse {
    my $self = shift;
    my $pattern = shift;

    # Adapted from Dancer::Route::make_regexp_from_route

    if ( $pattern =~ m/^\d+$/ ) {
        $pattern = "/([^/]+)" x $pattern;
    }
    else {

        $pattern =~ s#/+#/#g;

        # Parse .../*/...
        $pattern =~ s#\*#([^/]+)#g;

        # Escape '.'
        $pattern =~ s#\.#\\.#g;
    }

    $pattern = "^$pattern";

    return qr/$pattern/;
}

sub match {
    my $self = shift;
    my $path = shift;

    return Path::WalkURI::Rule::Regexp->regexp_match( $path, $self->regexp );
}

1;
