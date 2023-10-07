/*
 * Floret Tiling - Cover area using floret pentagonal tiles
 * https://en.wikipedia.org/wiki/Snub_trihexagonal_tiling#Floret_pentagonal_tiling
 */

$fn = $preview ? 32 : 64;

module floret_rod(a, b, thickness) {
    diff = b-a; beta = atan2(diff.x, diff.y); v = [-cos(beta)*0.5*thickness, sin(beta)*0.5*thickness];
    linear_extrude(thickness) {
        polygon([a-v, a+v, b+v, b-v]);
    }
}

function floret_edges(side) =
    let (y=side*cos(30), h=side/tan(30)+y)
        [[-0.5*side, 0], [0.5*side, 0], [side, y], [0, h], [-side, y]];

function floret_petal_height(side) =
    side*(1/tan(30) + cos(30));

function floret_long_side(side) =
    side*sqrt(1/tan(30)^2+1);

module floret_petal_frame(side, thickness) {
    edges = floret_edges(side);
    for (i = [0:3]) {
        floret_rod(edges[i], edges[i+1], thickness);
    }
    floret_rod(edges[4], edges[0], thickness);
}

module floret_petal_solid(side, thickness) {
    linear_extrude(thickness) polygon(floret_edges(side));
}

module floret_frame(side, thickness, angle_off) {
    h = floret_petal_height(side);
    for (angle=[30, 90, 150, 210, 270, 330]) {
        rotate(angle+angle_off, [0,0,1]) translate([0, h, 0]) mirror([0, 1, 0]) floret_petal_frame(side, thickness);
    }
}

module floret_solid(side, thickness, angle_off) {
    h = floret_petal_height(side);
    for (angle=[30, 150, 270]) {
        rotate(angle+angle_off, [0,0,1]) translate([0, h, 0]) mirror([0, 1, 0]) floret_petal_frame(side, thickness);
        rotate(angle+angle_off+60, [0,0,1]) translate([0, h, 0]) mirror([0, 1, 0]) floret_petal_solid(side, thickness);
    }
}

function floret_unseen(floret, done) =
    let (found = search([floret], done)) len(done) == 0 || found[0] == [];

function floret_point_inbounds(x, y, width, height) =
    x>=0 && x<=width && y>=0 && y<=height;

function floret_inbounds(floret, side, width, height) =
    let (h = floret_petal_height(side), v = floret_long_side(side)+side*cos(60))
        floret_point_inbounds(floret.x-h, floret.y, width, height)
     || floret_point_inbounds(floret.x+h, floret.y, width, height)
     || floret_point_inbounds(floret.x, floret.y-v, width, height)
     || floret_point_inbounds(floret.x, floret.y+v, width, height);

function floret_petal_offset(side, angle_off) =
    let (long = floret_long_side(side), y=2*long+side*cos(60), x=side*sin(60))
        [x*cos(angle_off)-y*sin(angle_off), y*cos(angle_off)+x*sin(angle_off)];

module floret_tile_frame_recursive(side, thickness, width, height, todo, done, count) {
    count_limit = 10000;
    floret = todo[0];
    angle_off = floret[2] % 360;
    remaining_todo = len(todo) == 1 ? [] : [ for (i=[1:len(todo)-1]) todo[i] ];
    approx_pos = [round(floret.x), round(floret.y)];
    if (floret_inbounds(floret, side, width, height) && floret_unseen(approx_pos, done) && count<count_limit) {
        translate([floret.x, floret.y, 0]) floret_frame(side, thickness, angle_off);
        offset = 2*floret_long_side(side);
        new_work = [
            for (i=[0:5]) let(angle=angle_off+i*60)
                concat([floret.x, floret.y]+floret_petal_offset(side, angle), [angle])
        ];
        floret_tile_frame_recursive(side, thickness, width, height,
            concat(remaining_todo, new_work), concat(done, [approx_pos]), count+1);
    } else if (len(remaining_todo) > 0 && count<count_limit) {
        floret_tile_frame_recursive(side, thickness, width, height, remaining_todo, done, count+1);
    }
}

module floret_tile_frame(side, thickness, angle_off, width, height) {
    intersection() {
        floret_tile_frame_recursive(side, thickness, width, height, [[0.5*width, 0.5*height, angle_off]], [], 0);
        cube([width, height, thickness]);
    }
}


module floret_tile_solid_recursive(side, thickness, width, height, todo, done, count) {
    count_limit = 10000;
    floret = todo[0];
    angle_off = floret[2] % 360;
    remaining_todo = len(todo) == 1 ? [] : [ for (i=[1:len(todo)-1]) todo[i] ];
    approx_pos = [round(floret.x), round(floret.y)];
    solid = floret[3];
    if (floret_inbounds(floret, side, width, height) && floret_unseen(approx_pos, done) && count<count_limit) {
        if (solid) {
            translate([floret.x, floret.y, 0]) floret_solid(side, thickness, angle_off);
        } else {
            translate([floret.x, floret.y, 0]) floret_frame(side, thickness, angle_off);
        }
        offset = 2*floret_long_side(side);
        new_work = [
            for (i=[0:5]) let(angle=angle_off+(i+1)*60)
                concat([floret.x, floret.y]+floret_petal_offset(side, angle), [angle+(solid?0:60), !solid || i%2==0])
        ];
        floret_tile_solid_recursive(side, thickness, width, height,
            concat(remaining_todo, new_work), concat(done, [approx_pos]), count+1);
    } else if (len(remaining_todo) > 0 && count<count_limit) {
        floret_tile_solid_recursive(side, thickness, width, height, remaining_todo, done, count+1);
    }
}

module floret_tile_solid(side, thickness, angle_off, width, height) {
    intersection() {
        floret_tile_solid_recursive(side, thickness, width, height, [[0.5*width, 0.5*height, angle_off, true]], [], 0);
        cube([width, height, thickness]);
    }
}

font="Liberation Sans:style=Bold";
thickness = 3.0;
engrave   = 1.5;

translate([0, 30]) floret_tile_solid(side=10, thickness=thickness, angle_off=0, width=200, height=200);
difference() {
    translate([-25, -10]) cube([250, 250, thickness]);
    translate([0, 30]) cube([200, 200, thickness]);
    translate([100, 0, thickness-engrave]) linear_extrude(engrave) text("Solid, 0 deg", font=font, size=20, halign="center");
}

translate([250, 30]) floret_tile_solid(side=10, thickness=thickness, angle_off=30, width=200, height=200);
difference() {
    translate([225, -10]) cube([250, 250, thickness]);
    translate([250, 30]) cube([200, 200, thickness]);
    translate([350, 0, thickness-engrave]) linear_extrude(engrave) text("Solid, 30 deg", font=font, size=20, halign="center");
}

translate([0, 280]) floret_tile_frame(side=10, thickness=thickness, angle_off=0, width=200, height=200);
difference() {
    translate([-25, 240]) cube([250, 250, thickness]);
    translate([0, 280]) cube([200, 200, thickness]);
    translate([100, 250, thickness-engrave]) linear_extrude(engrave) text("Frame, 0 deg", font=font, size=20, halign="center");
}

translate([250, 280]) floret_tile_frame(side=10, thickness=thickness, angle_off=30, width=200, height=200);
difference() {
    translate([225, 240]) cube([250, 250, thickness]);
    translate([250, 280]) cube([200, 200, thickness]);
    translate([350, 250, thickness-engrave]) linear_extrude(engrave) text("Frame, 30 deg", font=font, size=20, halign="center");
}
