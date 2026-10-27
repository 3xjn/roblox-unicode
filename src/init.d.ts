/** Unicode version of the bundled property data. */
export declare const version: string;
export interface Break { readonly position: number; readonly required: boolean }
export declare function lineBreakProperty(codePoint: number): LuaTuple<[string, number]>;
/** Positions are UTF-8 byte offsets, matching Luau string indexing. */
export declare function lineBreaks(text: string): LuaTuple<[Break[] | undefined, string | undefined]>;
