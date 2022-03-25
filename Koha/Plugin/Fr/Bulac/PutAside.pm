package Koha::Plugin::Fr::Bulac::PutAside;

# Copyright (C) 2021 BULAC <sigb@bulac.fr>
#
# This file is part of Koha::Plugin::Fr::Bulac::PutAside.
#
# Koha::Plugin::Fr::Bulac::PutAside is free software; you can
# redistribute it and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation; either
# version 3 of the License, or (at your option) any later version.
#
# Koha::Plugin::Fr::Bulac::PutAside is distributed in the hope that
# it will be useful, but WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha::Plugin::Fr::Bulac::PutAside; if not, see
# <http://www.gnu.org/licenses>.

use Modern::Perl;

use base qw(Koha::Plugins::Base);

use C4::Context;
use C4::Auth;
use C4::Biblio;
use C4::Reserves qw(CanItemBeReserved AddReserve ModReserveAffect);
use C4::Circulation qw(GetOpenIssue AddReturn);
use C4::Stats;

use Koha::DateUtils qw(dt_from_string output_pref);
use Koha::Items;
use Koha::Holds;

use Koha::Plugin::Fr::Bulac::PutAside::i18n;

our $VERSION = "0.2.4";

our $metadata = {
    name            => 'Putaside',
    author          => 'Nicolas Legrand',
    date_authored   => '2021-04-02',
    date_updated    => "2021-04-12",
    minimum_version => '20.05.00.000',
    maximum_version => undef,
    version         => $VERSION,
    description     => 'This plugin is about puting aside onsite checked out items. The item is then marked as a hold, waiting at the current library for the same patron. If there is already a hold on the item, the current patron has the priority.',

};

sub new {
    # entirely taken from
    # https://github.com/bywatersolutions/koha-plugin-kitchen-sink/blob/master/Koha/Plugin/Com/ByWaterSolutions/KitchenSink.pm
    my ( $class, $args ) = @_;

    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    my $self = $class->SUPER::new($args);

    
    
    return $self;
}

sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $template = $self->get_template({ file => 'configure.tt' });
    if ( $cgi->param('save') ) {
        my $myconf;
        $myconf->{putaside_itemtypes} = join(",", $cgi->multi_param('putaside_itemtypes'));
        if ( $myconf ) {
            $self->store_data($myconf);
            $template->param( 'config_success' => 'CONF_SUCCESS' );
        }
    }
    my @putaside_itemtypes;
    if (my $sitypes = $self->retrieve_data('putaside_itemtypes')) {
        @putaside_itemtypes = split(',', $sitypes);
    }
    my $itemtypes = Koha::ItemTypes->search_with_localization;
    $template->param(
        putaside_itemtypes  => \@putaside_itemtypes,
        itemtypes           => $itemtypes,
        );
    $self->output_html( $template->output() );
}

sub tool {
    my ( $self, $args ) = @_;

    my $cgi = $self->{'cgi'};

    $self->tool_putaside();
    
}

sub tool_putaside {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $branch = C4::Context->userenv->{'branch'};
    my $desk_id = C4::Context->userenv->{"desk_id"} || '';
    my @itypes = split(/,/,$self->retrieve_data('putaside_itemtypes'));
    my $errors = {};
    my $item;
    my $resid;
    my $barcode = $cgi->param('barcode') || '';
    $barcode =~ s/^\s+//;
    $barcode =~ s/\s+$//;
    chomp($barcode);

    if ($barcode) {
        $item =  Koha::Items->find({ barcode => $barcode });
        my $itype = $item->itype;
        if ( ! $item->itemnumber ) {
            $errors->{'BAD_BARCODE'} = $barcode ;
        }
        else {
            my $openissue = GetOpenIssue($item->itemnumber);
            if (! $openissue) {
                $errors->{'NOT_ONLOAN'} = $barcode ;
            }
            elsif (! grep(/^$itype$/,@itypes) ) {
                $errors->{'BAD_ITYPE'} = $itype;
            }
            else {
                my $borrowernumber = $openissue->{'borrowernumber'};
                my ($ret, $messages ) = AddReturn($barcode, $branch);
                if ($ret != 0) {

                    # AddReturn has a lot of return possibilities and
                    # a none zero return does'nt mean it wasn't
                    # properly returned.  So don't fail here on a non
                    # zero return value, but log it anyway for debug
                    # purposes...
 
                    while (my ($key, $value) = each %$messages) { 
                        warn "Can't return "
                            . $item->barcode
                            . " ("
                            . $item->itemcallnumber
                            . ") "
                            . $key
                            . " => "
                            . $value ;
                    }
                }
                my $canitembereserved = CanItemBeReserved( $borrowernumber, $item->itemnumber );
                if ($canitembereserved->{'status'} eq 'OK') {
                    my $error;
                    $resid = AddReserve({
                        branchcode       => $branch,
                        borrowernumber   => $borrowernumber,
                        biblionumber     => $item->biblionumber,
                        priority         => 0,
                        reservation_date => output_pref({ dt => dt_from_string, dateformat => 'iso' , dateonly => 1 }),
                        itemnumber       => $item->itemnumber,
                        found            => 'W',
                        itemtype         => $item->itype,
                        notes            => 'put aside',
                                               });
                    if ($desk_id) {
                        # Can't affect desk via AddReserve, so use ModReserveAffect
                        ModReserveAffect( $item->itemnumber, $borrowernumber, '', $resid, $desk_id);
                    }

                }
                else {
                    $errors->{'CANT_RESERVE'} = $borrowernumber ;
                }
            }
        }
    }
    my $template = $self->get_template({ file => 'tool-PutAside.tt' });
    $template->param(
        item => $item,
        errors => $errors,
        );
    if ($resid) {
        my $reserve = Koha::Holds->find($resid);
        $template->param(
            resid => $resid,
            reserve => $reserve,
            ); 
    }
    $self->output_html( $template->output() );
}

sub intranet_head {
}

sub intranet_js {
    #Inject links to the plugin
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
        my $lang = C4::Languages::getlanguage($cgi);
    my $js_strings;
    if (exists $i18n->{$lang}) {
        $js_strings = $i18n->{$lang};
    }
    else {
        $js_strings = $i18n->{en};
    }
    my $circ_button = '<li><a class="circ-button" href="/cgi-bin/koha/plugins/run.pl?class=Koha%3A%3APlugin%3A%3AFr%3A%3ABulac%3A%3APutAside&method=tool"><i class="fa fa-spinner"></i> '. $js_strings->{putaside} .'</a></li>';

     return q|
         <script>
$(document).ready(function(){

    $("#header > ul#toplevelmenu > li").first().after("<li><a href='/cgi-bin/koha/plugins/run.pl?class=Koha%3A%3APlugin%3A%3AFr%3A%3ABulac%3A%3APutAside&method=tool'> |.  $js_strings->{putaside} .q| </li>");
    if (pathname.search(/circulation-home.pl/) >= 0 ) {
      $( "ul.buttons-list:first > li:nth-child(2)" ).after('|. $circ_button.q|');
    }

});
         </script>
         |;
}
    
sub uninstall {
    my ( $self, $args ) = @_;
    # Nothing to do right now...
    1;
}

1;

