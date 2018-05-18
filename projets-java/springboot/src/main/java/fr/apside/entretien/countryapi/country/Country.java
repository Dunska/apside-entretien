package fr.apside.entretien.countryapi.country;



import javax.persistence.Entity;
import javax.persistence.Id;


@Entity
public class Country {

        private String code;

        private String code2;

        private String name;

        private String continent;

        private Long population;

        public Country() {
        }

        @Id
        public String getCode() {
                return code;
        }

        public void setCode(String code) {
                this.code = code;
        }

        public String getCode2() {
                return code2;
        }

        public void setCode2(String code2) {
                this.code2 = code2;
        }

        public String getName() {
                return name;
        }

        public void setName(String name) {
                this.name = name;
        }

        public String getContinent() {
                return continent;
        }

        public void setContinent(String continent) {
                this.continent = continent;
        }

        public Long getPopulation() {
                return population;
        }

        public void setPopulation(Long population) {
                this.population = population;
        }
}
