const BASE = '';

export interface Allergen {
  id: number;
  name: string;
  description?: string;
}

export interface FoodItem {
  id: number;
  name: string;
  description?: string;
  category?: string;
  image_path?: string;
  allergens: Allergen[];
}

export interface RecipeAllergen {
  name: string;
  count: number;
  items: string[];
}

export interface Recipe {
  id: number;
  name: string;
  description?: string;
  items: FoodItem[];
  allergens: RecipeAllergen[];
}

export interface SuggestResult {
  items: { id: number; name: string; category?: string }[];
  recipes: { id: number; name: string; type: string }[];
}

export async function getAllergens(): Promise<Allergen[]> {
  const r = await fetch(`${BASE}/allergens`);
  return r.json();
}

export async function createAllergen(name: string): Promise<Allergen> {
  const r = await fetch(`${BASE}/allergens`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name, description: '' }),
  });
  return r.json();
}

export async function getFoodItems(): Promise<FoodItem[]> {
  const r = await fetch(`${BASE}/food-items`);
  return r.json();
}

export async function getFoodItem(id: number): Promise<FoodItem> {
  const r = await fetch(`${BASE}/food-items/${id}`);
  return r.json();
}

export async function updateFoodItem(id: number, data: Partial<FoodItem> & { allergen_ids?: number[] }): Promise<FoodItem> {
  const r = await fetch(`${BASE}/food-items/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  return r.json();
}

export async function deleteFoodItem(id: number): Promise<void> {
  await fetch(`${BASE}/food-items/${id}`, { method: 'DELETE' });
}

export async function suggest(q: string): Promise<SuggestResult> {
  const r = await fetch(`${BASE}/food-items/suggest?q=${encodeURIComponent(q)}`);
  return r.json();
}

export async function scanImage(file: File): Promise<{ image_path: string; detected_allergens: Allergen[]; all_allergens: Allergen[] }> {
  const fd = new FormData();
  fd.append('file', file);
  const r = await fetch(`${BASE}/scan`, { method: 'POST', body: fd });
  return r.json();
}

export async function createFoodItem(data: { name: string; description?: string; category?: string; image_path?: string; allergen_ids: number[] }): Promise<FoodItem> {
  const r = await fetch(`${BASE}/food-items`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  return r.json();
}

export async function getRecipes(): Promise<Recipe[]> {
  const r = await fetch(`${BASE}/recipes`);
  return r.json();
}

export async function getRecipe(id: number): Promise<Recipe> {
  const r = await fetch(`${BASE}/recipes/${id}`);
  return r.json();
}

export async function createRecipe(data: { name: string; description?: string; food_item_ids: number[] }): Promise<Recipe> {
  const r = await fetch(`${BASE}/recipes`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  return r.json();
}

export async function updateRecipe(id: number, data: { name?: string; description?: string; food_item_ids?: number[] }): Promise<Recipe> {
  const r = await fetch(`${BASE}/recipes/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  return r.json();
}

export async function deleteRecipe(id: number): Promise<void> {
  await fetch(`${BASE}/recipes/${id}`, { method: 'DELETE' });
}
