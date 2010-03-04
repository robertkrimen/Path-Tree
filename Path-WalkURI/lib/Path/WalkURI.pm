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

    $_ = "/$_";
    s#/+#/#g;

    return $_;
}

sub consume {
    my $self = shift;
    my $step = shift;
    my $regexp = shift;

    my $path = $step->leftover;

    my @captured;
    my @match = $path =~ $regexp;

    if ( defined $1 ) {
        @captured = @match;
    }
    elsif ( $match[0] ) {
    }
    else {
        return;
    }

    my $leftover = eval q{$'};
    my $segment = substr $path, 0, -1 * length $leftover;
    my $prefix = $step->prefix . $step->segment;

    return {
        captured => \@captured,
        leftover => $leftover,
        segment => $segment,
        prefix => $prefix,
    };
}

package Path::WalkURI::RegexpRule;

sub parse {
    my $self = shift;
    my $input = shift;

    # Adapted from Dancer::Route::make_regexp_from_route

    my $pattern = $input;

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

1;
