package Path::Tree::DataMapper;

use Any::Moose;

has rulelist => qw/ is ro lazy_build 1 isa ArrayRef /;
sub _build_rulelist { [] };

has fallback => qw/ is rw isa CodeRef|Path::Tree::DataMapper /;

sub map {
    my $self = shift;
    my $input = shift;

    my $map = Path::Tree::DataMapper::Map->new( mapper => $self, input => $input );

    my @rulelist = @{ $self->rulelist };
    for my $rule (@rulelist) {

        local $_ = $map->input;

        if ( my $matcher = $rule->matcher ) {
            next unless $matcher->( $map, $_ );
        }

        my @result = $rule->mapper->( $map, $_ );
        if      ( $map->success )     {}
        elsif   ( $map->failure )     {}
        elsif   ( @result && ref $result[0] eq 'Path::Tree::DataMapper' )
                                        { $map = $result[0] }
        elsif   ( @result )             { $map->result( $result[0] ) }
        else                            { next }

        last;

    }

    unless ( $map->done ) {
        if ( my $fallback = $self->fallback ) {
            if ( ref $fallback eq 'CODE' ) {
                return $fallback->( $map, $map->input );
            }
            else {
                return $fallback->map( $map->input );
            }
        }
    }

    return $map;
}

sub rule {
    my $self = shift;
    my ( $matcher, $mapper );
    $matcher = shift if @_ > 1;
    $mapper = shift;

    die "Missing mapper" unless $mapper;
    die "Invalid mapper ($mapper)" unless ref $mapper eq 'CODE';

    my @arguments;
    if ( $matcher ) {
        my $matcher_;
        if      ( ref $matcher eq 'CODE' )      {}
        elsif   ( ref $matcher eq 'Regexp' )    { $matcher_ = sub { $_ =~ $matcher } }
        elsif   ( ref $matcher eq '' &&
                  $matcher =~ m/^(?:CODE|HASH|ARRAY|SCALAR|Regexp)$/x )
                                                { $matcher_ = sub { ref $_ eq $matcher } }
        else                                    { die "Invalid matcher ($matcher)" }
        $matcher_ ||= $matcher;
        push @arguments, matcher => $matcher_;
    }

    my $rule = Path::Tree::DataMapper::Rule->new( mapper => $mapper, @arguments );
    push @{ $self->rulelist }, $rule;
}

package Path::Tree::DataMapper::Map;

use Any::Moose;

has mapper => qw/ is ro required 1 isa Path::Tree::DataMapper /;
has input => qw/ is ro required 1 /;
has result => qw/ accessor _result predicate success /;
has error => qw/ is rw predicate failure /;

sub result {
    my $self = shift;
    return $self->_result( shift ) if @_;
    die "Missing result" unless $self->success;
    return $self->_result;
}

sub map {
    my $self = shift;
    my $input = shift;
    my $map = $self->mapper->map( $input );
    $self->map( $map );
}

sub done { $_[0]->success || $_[0]->failure }

package Path::Tree::DataMapper::Rule;

use Any::Moose;

has matcher => qw/ is ro isa Maybe[CodeRef] /;
has mapper => qw/ is ro required 1 isa CodeRef /;

1;
