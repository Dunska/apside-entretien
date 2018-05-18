import { Country } from "./country";
import { Input, Component } from "@angular/core";

@Component({
    selector: 'country-card',
    templateUrl: './country.card.html'
  })
export class CountryCard {
  
    @Input() country: Country;
  
    constructor() {
    }

}
