using Franklin
const F = Franklin

html(s) = "\n~~~$s~~~\n"

function hfun_adddescription()
    d = locvar(:description)
    isnothing(d) ? "" : F.fd2html(d, internal=true)
end

function hfun_frontmatter()
    fm = locvar(:front_matter)
    if isnothing(fm)
        ""
    else
        """
        <d-front-matter>
            <script id="distill-front-matter" type="text/json">
                $fm
            </script>
        </d-front-matter>
        """
    end
end

function hfun_byline()
    fm = locvar(:front_matter)
    if isnothing(fm)
        ""
    else
        "<d-byline></d-byline>" 
    end
end

function hfun_dtoc()
    is_enable_toc = locvar(:is_enable_toc)
    minlevel = locvar("mintoclevel")
    maxlevel = locvar("maxtoclevel")
    toc = F.hfun_toc([string(minlevel), string(maxlevel)])
    if isnothing(is_enable_toc) || !is_enable_toc
        ""
    else
        """
        <hr class="franklin-toc-separator">
        <d-article class="franklin-content">
        <h3 class="franklin-toc-header">Table of content</h3>
        $toc
        </d-article>
        <hr class="franklin-toc-separator">
        """
    end
end

function hfun_appendix()
    ap = locvar(:appendix)
    ap = isnothing(ap) ? "" : F.md2html(ap)
    bib = locvar(:bibliography)
    if isnothing(bib)
        bib = ""
    else
        bib_in_cur_folder = joinpath(splitdir(locvar("fd_rpath"))[1], bib)
        if isfile(bib_in_cur_folder)
            bib_resolved = F.parse_rpath("/" * bib_in_cur_folder)
        else
            bib_resolved = F.parse_rpath(bib; canonical=false, code=true)
        end
        bib = "<d-bibliography src=\"$bib_resolved\"></d-bibliography>"
    end
    """
    <d-appendix>
        $ap
        $bib
    </d-appendix>
    """
end

function lx_dcite(lxc,_)
    content = F.content(lxc.braces[1])
    "<d-cite key=\"$content\"></d-cite>" |> html
end

function dfigure(layout, src, caption)
    """
    <figure class="l-$layout text-center">
        <img src="$src">
        <figcaption>$caption</figcaption>
    </figure>
    """ |> html
end

# https://github.com/distillpub/template/blob/b854bd0124911e1be4744e472b67832e3251b96c/src/styles/styles-layout.css#L137-L166
"""
Possible layouts:
"""
function lx_dfig(lxc,lxd)
    content = F.content(lxc.braces[1])
    info = split(content, ';')
    layout = info[1]
    src = info[2]
    caption = F.reprocess(join(info[3:end], ';'), lxd)

    # (case 1) it is a figure from network
    startswith(src, "http") && return dfigure(layout, src, caption)

    # (case 2) it's in current folder
    src_in_cur_folder = joinpath(splitdir(locvar("fd_rpath"))[1], src)
    if isfile(src_in_cur_folder)
        src_resolved = F.parse_rpath("/" * src_in_cur_folder)
        @info "resolving fig path" src src_resolved
        return dfigure(layout, src_resolved, caption)
    end

    # (case 3) assume it is generated by code
    src = F.parse_rpath(src; canonical=false, code=true)

    # !!! directly take from `lx_fig` in Franklin.jl
    fdir, fext = splitext(src)

    # there are several cases
    # A. a path with no extension --> guess extension
    # B. a path with extension --> use that
    # then in both cases there can be a relative path set but the user may mean
    # that it's in the subfolder /output/ (if generated by code) so should look
    # both in the relpath and if not found and if /output/ not already last dir
    candext = ifelse(isempty(fext),
                     (".png", ".jpeg", ".jpg", ".svg", ".gif"), (fext,))
    for ext ∈ candext
        candpath = fdir * ext
        syspath  = joinpath(F.PATHS[:site], split(candpath, '/')...)
        isfile(syspath) && return dfigure(layout, candpath, caption)
    end
    # now try in the output dir just in case (provided we weren't already
    # looking there)
    p1, p2 = splitdir(fdir)
    @debug "TEST" p1 p2
    if splitdir(p1)[2] != "output"
        for ext ∈ candext
            candpath = joinpath(splitdir(p1)[1], "output", p2 * ext)
            syspath  = joinpath(F.PATHS[:site], split(candpath, '/')...)
            isfile(syspath) && return dfigure(layout, candpath, caption)
        end
    end
end

function lx_aside(lxc,lxd)
    content = F.reprocess(F.content(lxc.braces[1]), lxd)
    "<aside>$content</aside>" |> html
end

function lx_footnote(lxc,lxd)
    content = F.reprocess(F.content(lxc.braces[1]), lxd)
    # workaround
    if startswith(content, "<p>")
        content = content[4:end-5]
    end
    "<d-footnote>$content</d-footnote>" |> html
end

function lx_appendix(lxc,lxd)
    content = F.reprocess(F.content(lxc.braces[1]), lxd)
    "<d-appendix>$content</d-appendix>" |> html
end