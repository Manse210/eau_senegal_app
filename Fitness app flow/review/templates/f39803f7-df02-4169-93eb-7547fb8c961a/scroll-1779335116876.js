(function(window, undefined) {

    /*********************** START STATIC ACCESS METHODS ************************/

    var older = jimUtil.loadScrollBars;
    jQuery.extend(jimUtil, {
        "loadScrollBars": function() {
        	if (older != undefined)
        		older();
            jQuery("div[class*='t-f39803f7-df02-4169-93eb-7547fb8c961a']:not([class*=' s-']) .ui-page").overscroll({ showThumbs:true, direction:'multi', roundCorners:true, backgroundColor:'black', opacity:'0.45', thickness:'3', scrollSpacing:'2.5'});
         }
    });

    /*********************** END STATIC ACCESS METHODS ************************/

}) (window);