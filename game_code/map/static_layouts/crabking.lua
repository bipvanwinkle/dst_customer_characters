return {
  version = "1.1",
  luaversion = "5.1",
  orientation = "orthogonal",
  width = 10,
  height = 10,
  tilewidth = 64,
  tileheight = 64,
  properties = {},
  tilesets = {
    {
      name = "ground",
      firstgid = 1,
      filename = "../../../../tools/tiled/dont_starve/ground.tsx",
      tilewidth = 64,
      tileheight = 64,
      spacing = 0,
      margin = 0,
      image = "../../../../tools/tiled/dont_starve/tiles.png",
      imagewidth = 512,
      imageheight = 512,
      properties = {},
      tiles = {}
    }
  },
  layers = {
    {
      type = "tilelayer",
      name = "BG_TILES",
      x = 0,
      y = 0,
      width = 10,
      height = 10,
      visible = true,
      opacity = 1,
      properties = {},
      encoding = "lua",
      data = {
        0, 0, 26, 26, 26, 26, 26, 26, 26, 0,
        0, 26, 26, 26, 26, 26, 26, 26, 26, 0,
        26, 26, 26, 26, 26, 26, 26, 26, 26, 0,
        26, 26, 26, 26, 26, 26, 26, 26, 26, 26,
        26, 26, 26, 26, 26, 26, 26, 26, 26, 26,
        26, 26, 26, 26, 26, 26, 26, 26, 26, 26,
        26, 26, 26, 26, 26, 26, 26, 26, 26, 26,
        0, 26, 26, 26, 26, 26, 26, 26, 26, 26,
        0, 26, 26, 26, 26, 26, 26, 26, 26, 26,
        0, 0, 26, 26, 26, 26, 26, 26, 0, 0
      }
    },
    {
      type = "objectgroup",
      name = "FG_OBJECTS",
      visible = true,
      opacity = 1,
      properties = {},
      objects = {
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 83,
          y = 145,
          width = 44,
          height = 23,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 218,
          y = 37,
          width = 25,
          height = 50,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 111,
          y = 204,
          width = 18,
          height = 55,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 531,
          y = 250,
          width = 21,
          height = 30,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 172,
          y = 63,
          width = 15,
          height = 59,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 516,
          y = 205,
          width = 54,
          height = 16,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 270,
          y = 67,
          width = 54,
          height = 16,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 160,
          y = 218,
          width = 15,
          height = 59,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 71,
          y = 319,
          width = 58,
          height = 23,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 574,
          y = 275,
          width = 15,
          height = 59,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 527,
          y = 357,
          width = 15,
          height = 59,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 576,
          y = 387,
          width = 34,
          height = 27,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 414,
          y = 504,
          width = 78,
          height = 25,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 578,
          y = 447,
          width = 15,
          height = 59,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 268,
          y = 534,
          width = 15,
          height = 59,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 195,
          y = 515,
          width = 41,
          height = 18,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 122,
          y = 362,
          width = 15,
          height = 59,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 117,
          y = 478,
          width = 25,
          height = 33,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 114,
          y = 89,
          width = 28,
          height = 27,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "crabking_spawner",
          shape = "rectangle",
          x = 321,
          y = 318,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 358,
          y = 46,
          width = 54,
          height = 16,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 496,
          y = 148,
          width = 54,
          height = 16,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 490,
          y = 468,
          width = 54,
          height = 16,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 100,
          y = 528,
          width = 54,
          height = 16,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 177,
          y = 552,
          width = 54,
          height = 16,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 202,
          y = 102,
          width = 78,
          height = 25,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 475,
          y = 56,
          width = 78,
          height = 25,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 28,
          y = 284,
          width = 78,
          height = 25,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 352,
          y = 557,
          width = 78,
          height = 25,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 384,
          y = 99,
          width = 34,
          height = 27,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 453,
          y = 99,
          width = 34,
          height = 27,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 84,
          y = 409,
          width = 34,
          height = 27,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 520,
          y = 504,
          width = 34,
          height = 27,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "stack_area",
          shape = "rectangle",
          x = 299,
          y = 524,
          width = 34,
          height = 27,
          visible = true,
          properties = {}
        }
      }
    }
  }
}
