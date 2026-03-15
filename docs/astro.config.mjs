// @ts-check
import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";

// https://astro.build/config
export default defineConfig({
  integrations: [
    starlight({
      title: "AVR-Zig",
      social: [
        {
          icon: "github",
          label: "GitHub",
          href: "https://github.com/arcembed/avr-zig",
        },
      ],
      sidebar: [
        {
          label: "Guides",
          autogenerate: { directory: "guides" },
        },
        {
          label: "Reference",
          items: [
            {
              label: "HAL",
              autogenerate: { directory: "reference/hal" },
            },
            {
              label: "Display Drivers",
              autogenerate: { directory: "reference/display" },
            },
            {
              label: "Sensor Drivers",
              autogenerate: { directory: "reference/sensor" },
            },
            {
              label: "Actuator Drivers",
              autogenerate: { directory: "reference/actuator" },
            },
            {
              label: "RFID Drivers",
              autogenerate: { directory: "reference/rfid" },
            },
            {
              label: "Platform",
              autogenerate: { directory: "reference/platform" },
            },
          ],
        },
      ],
    }),
  ],
});
