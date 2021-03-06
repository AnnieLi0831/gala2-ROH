# ==============================================================================
# Copyright 2018, Asthma Collaboratory
# coded by Kevin L. Keys, Pagé C. Goddard, Andrew Zeiger, Annie Li, Oona Risse-Adams
#
# This script contains several subroutines to facilitate plotting.
# It relies heavily on ggplot2 and other tidyverse packages.
# Source this script after setting the R environment, e.g.
#
#     source("set_R_environment.R")
#     source("plotting_routines.R")
#
# This ensures that all requisite libraries are loaded before defining the
# plotting functions contained herein.
#
# This script plotting_routines.R contains no executable code.
#
# It has no input or output.
# ==============================================================================

# ==============================================================================
# define functions here
# ==============================================================================

CreateManhattanPlot = function(df, threshold = 5e-8, highlight.SNPs = NULL, ylims = c(0,8), color = c("black", "blue"),
    title = "Manhattan plot", significance.threshold = 5e-8, suggestive.threshold = 1e-7, save.as = NULL){
    # Create a Manhattan Plot
    #
    # This function creates a Manhattan plot. It expects a data frame with the following four labeled columns:
    #     CHR: the chromosome to plot
    #     SNP: the single nucleotide polymorphisms (one per row)
    #     BP:  the base pair (position) of each SNP to plot
    #     P:   the p-value from the association test, one per SNP
    #
    # Args:
    #     df: data frame with colnames [SNP, CHR, BP, P]
    # 	  threshold: pvalue limit for labeling SNPs on the plot. SNPs with p-values greater than "threshold"
    #         are not plotted. BEWARE: high values of "threshold" can potentially lead to many SNPs
    #         being labeled and thereby make make plots unreadable!
    #         Default: 5e-8 (label any SNP with "standard" Bonferroni-corrected genome-wide significance)
    #     highlight.SNPs: vector of SNP ids to highlight,
    #         e.g.  highlight.SNPs = c("rs12345", "rs90181294", "rs556782")
    #         Default: NULL (no SNPs to highlight)
    #     ylim: the Y-axis limits for the plot
    #         e.g. [c(min,max)]
    #         Default: c(0,8), which plots p-values up to 1e-8
    #     color = a vector of colors (min 2 colors)
    #         e.g. [color = c("color1", "color2", "color3")]
    #         Default: c("black", "blue")
    #     title: an informative plot title
    #         Default: "Manhattan plot"
    #     significance.threshold: the Bonferroni significance threshold.
    #         Default: 5e-8 ("standard" genome-wide significance)
    #     suggestive.threshold: the suggestive threshold of significance.
    #         Default: 1e-7
    #     save.as: a filepath for saving the plot to file
    #         Default: NULL (do not save to file)
    # Outputs:
    #    g is a ggplot object containing the Manhattan plot

	# format df with (complicated) dplyr filtering
	df.tmp = df %>%

		# Compute chromosome size
		group_by(CHR) %>%
		summarise(chr_len = max(BP)) %>%

		# Calculate cumulative position of each chromosome
		mutate(tot = cumsum(chr_len) - chr_len) %>%
		select(-chr_len) %>%

		# Add this info to the initial dataset
		left_join(df, ., by = c("CHR" = "CHR")) %>%

		# Add a cumulative position of each SNP
		arrange(CHR, BP) %>%
		mutate(BPcum = BP + tot) %>%

		# Add highlight and annotation information
		mutate(is_highlight = ifelse(SNP %in% highlight.SNPs, "yes", "no")) %>%
		mutate(is_annotate = ifelse(P < threshold, "yes", "no"))  ### done filtering!

	# get chromosome center positions for x-axis
	axisdf = df.tmp %>% group_by(CHR) %>% summarize(center = (max(BPcum) + min(BPcum)) / 2 )

	# plot with filtered data frame
	# we will construct this ggplot stepwise
	g = ggplot(df.tmp, aes(x = BPcum, y = -log10(P)))

	# Show all points
	g = g + geom_point(aes(color = as.factor(CHR)), alpha = 0.8, size = 2) +
	scale_color_manual(values = rep(color, 22))

	# custom X axis
	# note: expand = c(0, 0) removes space between plot area and x axis
	g = g + scale_x_continuous(label = axisdf$CHR, breaks = axisdf$center) +
	scale_y_continuous(expand = c(0, 0), limits = ylims)

	# add plot and axis titles
	g = g + ggtitle(paste0(title)) + labs(x = "Chromosome")

	# add genome-wide significant.threshold and suggestive.threshold lines
	g = g + geom_hline(yintercept = -log10(significance.threshold), color = "red") +
	geom_hline(yintercept = -log10(suggestive.threshold), linetype = "dashed", color = "blue")

	# add highlighted points
	g = g + geom_point(data = subset(df.tmp, is_highlight == "yes"), color = "orange", size = 2)

	# add label using ggrepel to avoid overlapping
    df.label = df.tmp[df.tmp$is_annotate == "yes",]
    if (dim(df.label)[1] > 0) {
        g = g + geom_label_repel(
            data = df.label,
            aes(label = as.factor(SNP), alpha = 0.7),
            size = 5,
            force = 1.3
        )
    }

	# custom the theme
	g = g + theme_bw(base_size = 22) +
		theme(
			plot.title = element_text(hjust = 0.5),
			legend.position = "none",
			panel.border = element_blank(),
			panel.grid.major.x = element_blank(),
			panel.grid.minor.x = element_blank()
	)

    # save to file?
    if (!is.null(save.as)) {
        ggsave(save.as, plot = g)
    }

	return(g)
}

CreateQQPlot = function(df, title = "QQ Plot", subtitle = NULL, xlim = NULL, ylim = NULL, save.as = NULL) {
    # Create a Quantile-Quantile Plot
    #
    # This function creates a QQ plot of GWAS p-values. It expects a data frame with the following four labeled columns:
    #     CHR: the chromosome to plot
    #     SNP: the single nucleotide polymorphisms (one per row)
    #     BP:  the base pair (position) of each SNP to plot
    #     P:   the p-value from the association test, one per SNP
    #
    #
    # Args:
    #     df: data frame with colnames [SNP, CHR, BP, P]
    #     title: an informative plot title
    #         Default: "QQ Plot"
    #     subtitle: an informative plot subtitle
    #         Default: NULL (will actually output genomic lambda, e.g. "λ = 1.0")
    #     xlim, ylim: the X-axis Y-axis limits for the plot
    #         e.g. [xlim = c(xmin, xmax), ylim = c(ymin, ymax)]
    #         Default: NULL (use default axis limits)
    #     save.as: a filepath for saving the plot to file
    #         Default: NULL (do not save to file)
    # Outputs:
    #    g is a ggplot object containing the Manhattan plot

    # could theoretically use new ggplot2 3.0.0 functions for this
    # unfortunately, they do not handle -log10 transformed p-values nicely
    # code below is appropriate for untransformed p-values
    # note: the stat_qq() layer expects an aesthetic "sample"
    #g = ggplot(df, aes(sample = P)) + geom_qq(distribution = stats::qunif)
    #g = g + geom_qq_line(distribution = stats::qunif)

    # make a transformed copy of the p-values for plotting
    df.copy = data.frame("observed" = -log10(sort(df$P)), "expected" = -log10(ppoints(length(df$P))))
    g = ggplot(df.copy, aes(x = expected, y = observed)) + geom_point()

    # draw the qq-line
    g = g + geom_abline(intercept = 0, slope = 1, color = "red")

    # prettify the axis labels
    g = g + xlab("Theoretical Quantiles") + ylab("Sample Quantiles")

    # adjust the axis limits
    g = g + coord_cartesian(xlim = xlim, ylim = ylim)

    # compute genomic control factor
    # note that we operate on the original and untransformed p-values!
    # when adding title, also add subtitle with genomic lambda included
    qchi = qchisq(df$P, 1, lower.tail = FALSE)
    genomic.control.factor = median(qchi[!is.nan(qchi)], na.rm = TRUE) / qchisq(0.5, 1)
    g = g + labs(title = title, subtitle = bquote(lambda == .(genomic.control.factor)))

    # save to file?
    if (!is.null(save.as)) {
        ggsave(save.as, plot = g)
    }
    return(g)
}


DensityAndHistogramPlot = function(input.pheno, output.file, phenotype, title, subtitle = NULL, hist.binwidth = 1, hist.border.color = "blue1", hist.fill.color = "blue", alpha = 0.6, line.color = "blue", size = 3) {
    # DensityAndHistogramPlot()
    #
    # This function plots a Kernel density plot that overlays a histogram to show the distribution of a continuous variable
    #   The plot can display the distribution of the phenotype and can help you decide if you may need to transform your data set
    # Written by Annie Li
    #
    # Args:
    #     input.pheno: The input phenotype file containing the values for the continous phenotype
    #     output.pheno: The output file path containing the full path to the output destination and the name of the saved plot (Make sure it ends in a file extension such as .png or .pdf)
    #     phenotype: Name of column where your phenotype values are located
    #     title: Title of your plot
    #     subtitle: Subtitle of your plot (default is NULL)
    #     hist.binwidth: The binwidth size of the histogram (default is 1)
    #     hist.border.color: The color for the borders of the histogram (default color is "blue1")
    #     hist.fill.color: The color for the histogram body (fill) (default color is "blue")
    #     alpha: The transparency level of the histogram (default is 0.6)
    #     line.color: The color for the Kernel density line (default color is "blue")
    #     size: The thickness of the Kernel density line (default size is 3)
    #
    # The color names can be found here: http://www.stat.columbia.edu/~tzheng/files/Rcolor.pdf
    #   Please use one color scheme for each phenotype
    #
    # PUT QUOTES "" AROUND ALL YOUR INPUT NAMES
    #
    # Output: a kernel density plot overlaying a histogram for your continuous phenotype


    # Load the phenotype file
    pheno = fread(input.pheno)

    # Plot the phenotype data
    # Note:
    #   ggplot(<data>, aes(x = <data on x-axis>)) +         *aes_string() if the input is a character string or contains quotes
    #       geom_histogram(aes(y = ..density..))            Specify y = ..density.. so that you can plot the Kernel density line
    pheno.plot = ggplot(pheno, aes_string(x = phenotype)) +
        geom_histogram(aes(y = ..density..), binwidth = hist.binwidth, color = hist.border.color, fill = hist.fill.color, alpha = alpha) +
        geom_density(color = line.color, size = size) +
        labs(title = title, subtitle = subtitle)

    # Save the plot
    ggsave(filename = output.file, plot = pheno.plot)

    # return the plot
    return(pheno.plot)
}

RohPlot = function(input.df, phenotype, size, sig.probe, roh.title, roh.subtitle, output.dir, output.pfx) {
    # RohPlot
    #
    # This function produces a plot displaying the ROH data for a specific phenotype and population; the plot has Probes on the x-axis and the phenotype on the y-axis, each horizontal line represents the ROH for an individual in the population
    #
    # Arguments:
    #   input.df: The input data frame
    #   phenotype:  The column name that contains the phenotype values
    #   size: The size of each point on the graph
    #   sig.probe: The probe of interest, a vertical line will be plotted at the probe of interest 
    #   roh.title: The title of the ROH plot (default is "ROH vs. phenotype")
    #   roh.subtitle: The subtitle of the ROH plot (default is NULL)
    #       Note that adding a subtitle compresses the graph
    #   output.dir: The output directory
    #   output.pfx: The prefix of the saved plot names
    #
    # Output: A plot displaying the ROH data for a specific phenotype and population; the plot has Probes on the x-axis and the phenotype on the y-axis, each horizontal line represents the ROH for an individual in the population
    
    # Set the colors for the plot to be white for 0 and black for 1
    set.colors = c("0" = "white", "1" = "black")
    
    # Plot the data using ggplot()
    # The probes will be on the x-axis, while the sorted phenotype will be on the y-axis
    # Note that get() was used since the phenotype input is a character string, so get() will return the value of the character string, which is the column containing the phenotype values
    # The plot will be colored based on the ROH values 0 or 1, we will later use scale_color_manual() to reset the colors to white and black
    #   Note in aes() color must be a character value, so convert the ROH values to character values
    # geom_point() plots the points
    #   shape 15 is a square, so that ROH segments (with consecutive 1s) will form a line
    #   size adjusts for size of the point (in our case it is a square)
    #   geom_vline() plots a vertical line at the probe of interest
    #   The arguments in theme() are used to remove the gridded background, and to adjust the legend key
    # guides() is used to enlarge the size of the legend keys
    # labs() sets the labels of the title, subtitle, x-axis, y-axis, and legend 
    roh.plot = ggplot(data = input.df, aes(x = probe.order, y = pheno.order)) + 
        geom_point(shape = 15, size = size, aes(color = as.character(ROH))) +
        scale_color_manual(values = set.colors) +
        geom_vline(xintercept = sig.probe, color = "black", size = 1) +
        theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(), panel.background = element_blank(), axis.ticks.x = element_blank(), axis.ticks.y = element_blank(), axis.text.x = element_blank(), axis.text.y = element_blank(), legend.key = element_rect(color = "black", fill = "white", size = 1)) +
        guides(color = guide_legend(override.aes = list(size = 10))) +
        labs(title = roh.title, subtitle = roh.subtitle, x = "Probes", y = phenotype, color = "Probe in ROH")

    # Use ggsave() to save ggplots
    ggsave(file = paste0(output.dir, output.pfx, ".roh.png"), plot = roh.plot)
}

LancPlot = function(input.lanc, input.sum.lanc, input.roh.lanc, phenotype, colorblind.friendly = FALSE, size, lanc.sig.probe, sum.lanc.sig.probe, roh.lanc.sig.probe, ancestry.title = "Local Ancestry Plot", ancestry.subtitle = NULL, sum.title = "Local Ancestry Summary Plot", sum.subtitle = NULL, roh.lanc.title = "ROH Local Ancestry", roh.lanc.subtitle = NULL, output.dir, output.pfx) {
    # LancPlot
    #
    # This function plots the local ancestry plot for a specific phenotype, population, and region on a chromosome
    # Three different local ancestry plots will be created:
    #     1) For each probe and individual, the local ancestry will be plotted 
    #         The probe positions are on the x-axis, the phenotype values are on the y-axis, and each horizontal line represents each individual with segments of different colors representing different ancestry
    #     2) Summary plot for the local ancestry data
    #         For each probe, the mean of the phenotype values for each ancestry will be plotted
    #         The probe positions are on the x-axis and the phenotype values are on the y-axis
    #         Each probe will have a total of 3 points (1 for each ancestry)
    #     3) For probes in an ROH, the local ancestry data will be plotted
    #         The probe positions are on the x-axis and the phenotype values are on the y-axis
    #
    # Arguments:
    #     input.lanc: The input data frame for plotting the local ancestry data
    #     input.sum.lanc: The input data frame for plotting the summary local ancestry
    #     input.roh.lanc: The input data frame for plotting the local ancestry for the probes in an ROH
    #     colorblind.friendly: If TRUE, a color blind friendly palette is used instead of the normal red, blue, yellow scale for the ROH local ancestry plot (default is FALSE)
    #     phenotype: The name for the column containing the phenotype data
    #     size: The size of each point on the graph (default is 0.05)
    #     lanc.sig.probe: The probe of interest, a vertical line will be plotted at the probe of interest.This is for the local ancestry plot 
    #     sum.lanc.sig.probe: The probe of interest, a vertical line will be plotted at the probe of interest.This is for the summary local ancestry plot 
    #     roh.lanc.sig.probe: The probe of interest, a vertical line will be plotted at the probe of interest. This is for the ROH local ancestry plot.
    #     ancestry.title: The title of the local ancestry plot (default is "Local Ancestry Plot")
    #                   Note that adding a subtitle compresses the graph
    #     ancestry.subtitle: The subtitle of the local ancestry plot (default is NULL)
    #                   Note that adding a subtitle compresses the graph
    #     sum.title: The title of the summary local ancestry plot (default is "Local Ancestry Summary Plot")
    #     sum.subtitle: The subtitle of the summary local ancestry plot (default is NULL)
    #                   Note that adding a subtitle compresses the graph
    #     roh.lanc.title: The title of the ROH plot colored by ancestry (default is "ROH Local Ancestry Plot")
    #     roh.lanc.subtitle: The subtitle of the ROH plot colored by ancestry (default is NULL)
    #                   Note that adding a subtitle compresses the graph
    #     output.dir: The output directory
    #     output.pfx: The prefix of the saved plot names
    #                 The following suffix will be added:
    #                   ".lanc.png" for the local ancestry plot
    #                   ".sum.lanc.png" for the local ancestry summary plot
    #                   ".roh.lanc.png" for the ROH local ancestry plot
    #
    # ***Note that the first and second plots will contain haploid ancestry calls, while the third plot will contain diploid ancestry calls (due to the ROH data)
    
    # =================================================================
    # Plot local ancestry
    # =================================================================

    # Set the ancestry colors manually      
    set.colors = c("A" = "blue", "E" = "red", "N" = "yellow")
    
    # Plot the local ancestry data
    #   Note that we plot 2 sets of data using geom_point(), one for the first ancestry call and the other for the second ancestry call
    #   scale_color_manual() is used to manually set the ancestry colors
    #   geom_vline() plots a vertical line at the probe of interest
    #   The arguments in theme() are used to remove the gridded background
    #   The arguments in guides() are used to enlarge the legend so that it is legible
    #   labs() is used to label the plot
    local.ancestry.plot = ggplot() +
          geom_point(data = input.lanc, shape = 15, size = size, alpha = 0.5, aes(x = probe.order, y = pheno.order1, color = as.character(ancestry1))) +
          geom_point(data = input.lanc, shape = 15, size = size, alpha = 0.5, aes(x = probe.order, y = pheno.order2, color = as.character(ancestry2))) +
          scale_color_manual(values = set.colors) +
          geom_vline(xintercept = lanc.sig.probe, color = "black", size = 1) +
          theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(), panel.background = element_blank(), axis.ticks.x = element_blank(), axis.ticks.y = element_blank(), axis.text.x = element_blank(), axis.text.y = element_blank()) +
          guides(color = guide_legend(override.aes = list(size = 10))) +
          labs(title = ancestry.title, subtitle = ancestry.subtitle, x = "Probes", y = phenotype, color = "Probe in ROH")        
    
    # Save the plot
    ggsave(filename = paste0(output.dir, output.pfx, ".lanc.png"), plot = local.ancestry.plot)

    # =================================================================
    # Plot summary local ancestry 
    # =================================================================
    
    # Set line types for each ancestry
    set.linetypes = c("A" = "solid", "E" = "longdash", "N" = "twodash")

    # Plot the summary local ancestry plot
    #   Note that we plot 2 sets of data using geom_point(), one for the first ancestry call and the other for the second ancestry call
    #   geom_smooth() is used to plot the line of best fit
    #   scale_color_manual() is used to manually set the ancestry colors
    #   scale_linetype_manual() is used to manually assign each ancestry a line type
    #   The arguments in theme() are used to remove the gridded background and to enlarge the legend key
    #   labs() is used to label the plot
    local.ancestry.summarise.plot = ggplot(data = input.sum.lanc, aes(x = Probe, y = mean)) +
        geom_point(alpha = 0.1, aes(color = ancestry)) +
        geom_smooth(aes(linetype = ancestry, color = ancestry)) +
        geom_vline(xintercept = sum.lanc.sig.probe, color = "black", size = 1) +
        scale_color_manual(values = set.colors, name = "Probe in ROH") +
        scale_linetype_manual(values = set.linetypes, name = "Probe in ROH") +
        theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(), panel.background = element_blank(), legend.key.size = unit(5, "line")) +
        labs(title = sum.title, subtitle = sum.subtitle, x = "Probes", y = phenotype)        

    # Save the plot 
    ggsave(filename = paste0(output.dir, output.pfx, ".sum.lanc.png"), plot = local.ancestry.summarise.plot)

    # ====================================================================
    # Plot ROH and local ancestry data
    # ====================================================================

    # Set the color scheme for the heteroxygous and homozygous ancestry calls  
    if (colorblind.friendly == TRUE) {
        set.colors.roh.lanc = c("AA" = "grey30", "EE" = "#D55E00", "NN" = "turquoise", "EA" = "yellow", "AN" = "orange", "EN" ="#CC79A7")
    } else {
        set.colors.roh.lanc =  c("AA" = "blue", "EE" = "red", "NN" = "yellow", "EA" = "purple", "AN" = "green", "EN" = "orange")
    }
    
    # Plot the ROH local ancestry data
    #   geom_point() is used to plot the local ancestry data for ROH segments
    #   scale_color_manual() is used to manually set the ancestry colors
    #       The limits argument is added  to prevent levels from being dropped from the legend key if it is not being used, this way the legend is consistent between plots
    #   geom_vline() plots a vertical line at or near the location of the probe of interest
    #   The arguments in theme() are used to remove the gridded background
    #   The arguments in guides() are used to enlarge the legend so that it is legible
    #   labs() is used to label the plot
    roh.lanc.plot.clean = ggplot(data = input.roh.lanc, aes(x = probe.order, y = pheno.order, color = ancTypes)) +
        geom_point(shape = 15, size = size) +
        scale_color_manual(values = set.colors.roh.lanc, limits = c("AA", "AN", "EA", "EE", "EN", "NN")) +
        geom_vline(xintercept = roh.lanc.sig.probe, color = "black", size = 1) +
        theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(), panel.background = element_blank(), axis.ticks.x = element_blank(), axis.ticks.y = element_blank(), axis.text.x = element_blank(), axis.text.y = element_blank()) +
        guides(color = guide_legend(override.aes = list(size = 10))) +
        labs(title = roh.lanc.title, subtitle = roh.lanc.subtitle, x = "Probes", y = phenotype, color = "Probe in ROH")        
    
    # Save the plot 
    ggsave(filename = paste0(output.dir, output.pfx, ".roh.lanc.png"), plot = roh.lanc.plot.clean)

}

