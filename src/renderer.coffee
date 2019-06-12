module.exports =
class Renderer
    constructor: (@net, @parent) ->
        @iconify = false
        @layoutDirection = 'tb'
        @generateGraph()

    setupGraph: ->
        @graph = new dagreD3.graphlib.Graph()
        @graph.setDefaultEdgeLabel ( -> {} )
        @graph.setGraph
            rankdir: @layoutDirection
            ranksep: 30, # Vertical node separation
            nodesep: 10, # Horizontal node separation
            edgesep: 20, # Horizontal edge separation
            marginx:  0, # Horizontal graph margin
            marginy:  0  # Vertical graph margin

    generateGraph: ->
        @setupGraph()
        nodes = @net.sortTopologically()
        console.log(nodes)
        for node in nodes
            if node.isInGraph
                continue
            layers = [node].concat node.coalesce
            if layers.length>1
                # Rewire the node following the last coalesced node to this one
                lastCoalesed = layers[layers.length-1]
                for child in lastCoalesed.children
                    uberParents = _.clone child.parents
                    uberParents[uberParents.indexOf lastCoalesed] = node
                    child.parents = uberParents
            @insertNode layers

            for parent in node.parents
                tops = []
                bottom_set = new Set()
                for top in parent.tops
                    tops.push(top.name)
                for bottom in node.bottoms
                    bottom_set.add(bottom.name)

                intersection = new Set(tops.filter((x) => bottom_set.has(x)))
                if intersection.size != 1
                    throw "wtferror"

                intersection_array = Array.from(intersection);
                blob_name = "blob_" + intersection_array[0]
                @insertLink parent, node, blob_name
        for source in @graph.sources()
            (@graph.node source).class = 'node-type-source'
        for sink in @graph.sinks()
            (@graph.node sink).class = 'node-type-sink'
        @render()

    insertNode: (layers) ->
        baseNode = layers[0]
        nodeClass = 'node-type-'+baseNode.type.replace(/_/g, '-').toLowerCase()
        nodeLabel = ''
        for layer in layers
            layer.isInGraph = true
            nodeLabel += @generateLabel layer
        nodeDesc =
            labelType   : 'html'
            label       : nodeLabel
            class       : nodeClass
            layers      : layers
            rx          : 5
            ry          : 5
        if @iconify
            _.extend nodeDesc,
                shape: 'circle'
        @graph.setNode baseNode.name, nodeDesc

    generateBlobLabel: (name) ->
        if not @iconify
            '<div class="node-label">'+name+'</div>'
        else
            ''

    insertBlobNode: (layer, name) ->
        nodeDesc =
            labelType   : 'html'
            label       : @generateBlobLabel name
            class       : 'node-type-blob'
            layers      : [layer]
            rx          : 5
            ry          : 5
            shape       : 'ellipse'
        console.log("label: " + nodeDesc.label)
        if @iconify
            _.extend nodeDesc,
                shape: 'circle'
        @graph.setNode name, nodeDesc

    generateLabel: (layer) ->
        if not @iconify
            '<div class="node-label">'+layer.name+'</div>'
        else
            ''

    insertLink: (src, dst, blob_name) ->

        @insertBlobNode src ,blob_name
        console.log name
        @graph.setEdge src.name, blob_name,
            arrowhead : 'vee'
        @graph.setEdge blob_name, dst.name,
            arrowhead : 'vee'

    renderKey:(key) ->
        key.replace(/_/g, ' ')

    renderValue: (value) ->
        if Array.isArray value
            return value.join(', ')
        return value

    renderSection: (section) ->
        s = ''
        for own key of section
            val = section[key]
            isScalarArray = Array.isArray(val) and ((val.length==0) or (typeof val[0] isnt 'object'))
            isSection = (typeof val is 'object') and not isScalarArray
            if isSection
                s += '<div class="node-param-section-title node-param-key">'+@renderKey(key)+'</div>'
                s += '<div class="node-param-section">'
                for subSection in [].concat(val)
                  s += @renderSection subSection
            else
                s += '<div class="node-param-row">'
                s += '<span class="node-param-key">'+@renderKey(key)+': </span>'
                s += '<span class="node-param-value">'+@renderValue(val)+'</span>'
            s += '</div>'
        return s

    tipForNode: (nodeKey) ->
        node = @graph.node nodeKey
        s = ''
        for layer in node.layers
            s += '<div class="node-info-group">'
            s += '<div class="node-info-header">'
            s += '<span class="node-info-title">'+layer.name+'</span>'
            s += ' &middot; '
            s += '<span class="node-info-type">'+@renderKey(layer.type)+'</span>'
            if layer.annotation?
                s += ' &middot; <span class="node-info-annotation">'+layer.annotation+'</span>'
            s += '</div>'
            s += @renderSection layer.attribs
        return s

    render: ->
        svg = d3.select(@parent)
        svgGroup = svg.append('g')
        graphRender = new dagreD3.render()
        graphRender svgGroup, @graph

        # Size to fit.
        bbox = svgGroup.node().getBBox()
        svgGroup.attr('transform', 'translate('+Math.ceil(-bbox.x)+')')
        # The size does not include the stroke width. Include an additional margin.
        margin = 5
        svg.attr('width', Math.ceil(bbox.width+2*margin))
        svg.attr('height', Math.ceil(bbox.height+2*margin))

        # Configure Tooltips.
        tipPositions =
            tb:
                my: 'left center'
                at: 'right center'
            lr:
                my: 'top center'
                at: 'bottom center'
        that = @
        svgGroup.selectAll("g.node").each (nodeKey) ->
            position = tipPositions[that.layoutDirection]
            position.viewport = $(window)
            $(this).qtip
                content:
                    text: that.tipForNode nodeKey
                position: position
                show:
                    delay: 0
                    effect: false
                hide:
                    effect: false
