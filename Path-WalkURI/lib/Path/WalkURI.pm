package Path::WalkURI;

use strict;
use warnings;

use Any::Moose;

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

package Path::WalkURI::SimpleWalker;

use Any::Moose;

has path => qw/ is ro required 1 isa Str /;
has sequence => qw/ is ro isa ArrayRef /, default => sub { [] };

sub leftover {
    return shift->step->leftover;
}

sub BUILD {
    my $self = shift;
    $self->push( leftover => Path::WalkURI->normalize_path( $self->path ) );
}

sub parse_rule_into_regexp {
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

sub consume {
    my $self = shift;
    my $rule = shift;

    my $regexp = $self->parse_rule_into_regexp( $rule );

    return unless my $step = Path::WalkURI->consume( $self->step, $regexp );

    $self->push( %$step );

    return 1;
}

sub push {
    my $self = shift;

    my $step = Path::WalkURI::SimpleWalker::Step->new( @_ );
    push @{ $self->sequence }, $step;
    return $step;
}

sub step {
    my $self = shift;
    my $at = shift;
    $at = -1 unless defined $at;
    return $self->sequence->[ $at ];
}

package Path::WalkURI::SimpleWalker::Step;

use Any::Moose;

has [qw/ prefix leftover segment /] => qw/ is ro isa Str /, default => '';
has captured => qw/ is ro isa ArrayRef /, default => sub { [] };

1;
