use Test::Most;

plan qw/ no_plan /;

use Path::WalkURI::PlackDispatcher;

ok( 1 );

my ( $dispatcher );

$dispatcher = Path::WalkURI::PlackDispatcher->new;

$dispatcher->route(

    '/apple' => sub {
        diag "Apple";
    },

    '/*' => [
        '/cherry' => sub {
            diag "Cherry";
        },

        '/*/*' => sub {
            diag "/*/*";
        },

        sub {
            diag "After /*/*";
        },

        '' => sub {
            diag "/*";
        },

        -before => sub {
            diag "Before /*";
        },
    ],
);

$dispatcher->dispatch( '/apple' );
