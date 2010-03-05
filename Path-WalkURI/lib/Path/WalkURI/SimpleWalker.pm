package Path::WalkURI::SimpleWalker;

use Any::Moose;

use Path::WalkURI;

has path => qw/ is ro required 1 isa Str /;
has sequence => qw/ is ro isa ArrayRef /, default => sub { [] };

sub leftover {
    return shift->step->leftover;
}

sub BUILD {
    my $self = shift;
    $self->push( leftover => Path::WalkURI->normalize_path( $self->path ) );
}

sub consume {
    my $self = shift;
    my $input = shift;

    my $rule = Path::WalkURI->parse_rule( $input );

    return unless my $step = Path::WalkURI->consume( $self->step, $rule );

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
